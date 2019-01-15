// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

use failure::{err_msg, Error, ResultExt};
use fidl::endpoints::{create_endpoints, create_proxy, ClientEnd, RequestStream, ServerEnd,
                      ServiceMarker};
use fidl_fuchsia_developer_tiles as tiles;
use fidl_fuchsia_math::SizeF;
use fidl_fuchsia_modular::{SessionShellContextMarker, SessionShellContextProxy,
                           SessionShellMarker, SessionShellRequest, SessionShellRequestStream,
                           StoryProviderProxy, StoryProviderWatcherMarker,
                           StoryProviderWatcherRequest, StoryState};
use fidl_fuchsia_ui_input::{KeyboardEvent, KeyboardEventPhase, MODIFIER_LEFT_SUPER,
                            MODIFIER_RIGHT_SUPER};
use fidl_fuchsia_ui_policy::{KeyboardCaptureListenerHackMarker,
                             KeyboardCaptureListenerHackRequest, PresentationProxy};
use fidl_fuchsia_ui_viewsv1::{ViewManagerMarker, ViewManagerProxy, ViewProviderMarker,
                              ViewProviderRequest::CreateView, ViewProviderRequestStream};
use fidl_fuchsia_ui_viewsv1token::ViewOwnerMarker;
use fuchsia_app::{self as component, client::connect_to_service};
use fuchsia_async as fasync;
use fuchsia_zircon as zx;
use futures::{future::ready as fready, TryFutureExt, TryStreamExt};
use lazy_static::lazy_static;
use parking_lot::Mutex;
use std::sync::Arc;

mod ask_box;
mod view;

use crate::view::{ErmineView, ErmineViewPtr};

pub struct App {
    view_manager: ViewManagerProxy,
    views: Vec<ErmineViewPtr>,
    session_shell_context: SessionShellContextProxy,
    story_provider: StoryProviderProxy,
    presentation_proxy: Option<PresentationProxy>,
    next_key: u32,
}

pub type AppPtr = Arc<Mutex<App>>;

lazy_static! {
    pub static ref APP: AppPtr = App::new().expect("Unable to create ermine app");
}

impl App {
    pub fn new() -> Result<AppPtr, Error> {
        let view_manager = connect_to_service::<ViewManagerMarker>()?;
        let session_shell_context = connect_to_service::<SessionShellContextMarker>()?;
        let (story_provider, story_provider_end) = create_proxy()?;
        session_shell_context
            .clone()
            .get_story_provider(story_provider_end)?;

        let app = Arc::new(Mutex::new(App {
            view_manager,
            views: vec![],
            session_shell_context,
            story_provider,
            presentation_proxy: None,
            next_key: 1,
        }));
        app.lock().spawn_story_watcher()?;
        app.lock().setup_keyboard_hack()?;
        Ok(app)
    }

    pub fn spawn_view_provider_server(chan: fasync::Channel) {
        fasync::spawn(
            ViewProviderRequestStream::from_channel(chan)
                .try_for_each(move |req| {
                    let CreateView { view_owner, .. } = req;
                    APP.lock()
                        .create_view(view_owner)
                        .expect("Create view failed");
                    futures::future::ready(Ok(()))
                })
                .unwrap_or_else(|e| eprintln!("error running view_provider server: {:?}", e)),
        )
    }

    pub fn create_view(&mut self, req: ServerEnd<ViewOwnerMarker>) -> Result<(), Error> {
        let (view, view_server_end) = create_proxy()?;
        let (view_listener, view_listener_server) = zx::Channel::create()?;
        let view_listener_request = ServerEnd::new(view_listener_server);
        let (mine, theirs) = zx::EventPair::create()?;
        self.view_manager.create_view(
            view_server_end,
            req,
            ClientEnd::new(view_listener),
            theirs,
            None,
        )?;
        let (scenic, scenic_request) = create_proxy()?;
        self.view_manager.get_scenic(scenic_request)?;
        let view_ptr = ErmineView::new(view_listener_request, view, mine, scenic)?;
        self.views.push(view_ptr);
        Ok(())
    }

    pub fn watch_for_key_event(&mut self, code_point: u32, modifiers: u32) -> Result<(), Error> {
        let mut hotkey_event = KeyboardEvent {
            event_time: 0,
            device_id: 0,
            phase: KeyboardEventPhase::Released,
            hid_usage: 0,
            code_point: code_point,
            modifiers: modifiers,
        };
        let (event_listener_client, event_listener_server) = zx::Channel::create()?;
        let event_listener = ClientEnd::new(event_listener_client);
        let event_listener_request =
            ServerEnd::<KeyboardCaptureListenerHackMarker>::new(event_listener_server);

        self.presentation_proxy
            .clone()
            .ok_or_else(|| err_msg("clone failed"))?
            .capture_keyboard_event_hack(&mut hotkey_event, event_listener)?;

        fasync::spawn(
            event_listener_request
                .into_stream()?
                .try_for_each(move |event| match event {
                    KeyboardCaptureListenerHackRequest::OnEvent { event, .. } => {
                        APP.lock().handle_hot_key(&event).expect("handle hot key");
                        futures::future::ready(Ok(()))
                    }
                })
                .unwrap_or_else(|e| eprintln!("keyboard hack listener error: {:?}", e)),
        );

        Ok(())
    }

    pub fn setup_keyboard_hack(&mut self) -> Result<(), Error> {
        let (presentation_proxy, presentation_request) = create_proxy()?;
        self.session_shell_context
            .clone()
            .get_presentation(presentation_request)?;
        self.presentation_proxy = Some(presentation_proxy);

        self.watch_for_key_event(0x20, MODIFIER_LEFT_SUPER)?;
        self.watch_for_key_event(0x20, MODIFIER_RIGHT_SUPER)?;

        Ok(())
    }

    fn next_story_key(&mut self) -> u32 {
        let next_key = self.next_key;
        self.next_key += 1;
        next_key
    }

    pub fn request_start_story(&mut self, story_id: String) -> Result<(), Error> {
        let (story_controller, story_controller_end) = create_proxy()?;
        self.story_provider
            .get_controller(&story_id, story_controller_end)?;
        story_controller.request_start()?;
        Ok(())
    }

    pub fn remove_view_for_story(&mut self, story_id: String) -> Result<(), Error> {
        self.views[0].lock().remove_view_for_story(&story_id)
    }

    pub fn remove_story(&mut self, key: u32) -> Result<(), Error> {
        self.views[0].lock().remove_story(key)
    }

    pub fn list_stories(&self) -> (Vec<u32>, Vec<String>, Vec<SizeF>, Vec<bool>) {
        self.views[0].lock().list_stories()
    }

    pub fn add_child_view_for_story_attach(
        &mut self, story_id: String, view_holder_token: zx::EventPair,
    ) -> Result<(), Error> {
        let key_to_use = self.next_story_key();
        self.views[0].lock().add_child_view_for_story_attach(
            key_to_use,
            story_id,
            view_holder_token,
        )
    }

    pub fn spawn_tiles_server(chan: fasync::Channel) {
        fasync::spawn(
            tiles::ControllerRequestStream::from_channel(chan)
                .try_for_each(move |req| match req {
                    tiles::ControllerRequest::AddTileFromUrl { responder, .. } => {
                        eprintln!("error AddTileFromUrl no longr supported");
                        responder.control_handle().shutdown();
                        fready(Ok(()))
                    }
                    tiles::ControllerRequest::AddTileFromViewProvider { responder, .. } => {
                        eprintln!("error AddTileFromViewProvider no longr supported");
                        responder.control_handle().shutdown();
                        fready(Ok(()))
                    }
                    tiles::ControllerRequest::RemoveTile { key, .. } => {
                        APP.lock()
                            .remove_story(key)
                            .unwrap_or_else(|e| eprintln!("remove_story error: {:?}", e));
                        fready(Ok(()))
                    }
                    tiles::ControllerRequest::ListTiles { responder } => {
                        let (mut keys, mut urls, mut sizes, mut focusabilties) =
                            APP.lock().list_stories();
                        fready(responder.send(
                            &mut keys.iter_mut().map(|a| *a),
                            &mut urls.iter_mut().map(|a| &**a),
                            &mut sizes.iter_mut(),
                            &mut focusabilties.iter_mut().map(|a| *a),
                        ))
                    }
                    tiles::ControllerRequest::Quit { control_handle: _ } => ::std::process::exit(0),
                })
                .unwrap_or_else(|e| eprintln!("error running Tiles controller server: {:?}", e)),
        )
    }

    pub fn spawn_session_shell_server(chan: fasync::Channel) {
        fasync::spawn(
            #[allow(unreachable_patterns)]
            SessionShellRequestStream::from_channel(chan)
                .try_for_each(move |req| match req {
                    SessionShellRequest::AttachView {
                        view_id,
                        view_owner,
                        ..
                    } => {
                        println!("AttachView {:?}", view_id.story_id);
                        let view_holder_token: zx::EventPair =
                            zx::EventPair::from(zx::Handle::from(view_owner.into_channel()));
                        APP.lock()
                            .add_child_view_for_story_attach(view_id.story_id, view_holder_token)
                            .unwrap_or_else(|e| {
                                eprintln!("add_child_view_for_story_attach error: {:?}", e)
                            });
                        fready(Ok(()))
                    }
                    SessionShellRequest::DetachView { view_id, responder } => {
                        println!("DetachView {:?}", view_id.story_id);
                        fready(responder.send())
                    }
                    _ => fready(Ok(())),
                })
                .unwrap_or_else(|e| eprintln!("error running SessionShell server: {:?}", e)),
        )
    }

    pub fn spawn_story_watcher(&mut self) -> Result<(), Error> {
        let (story_watcher, story_watcher_request) =
            create_endpoints::<StoryProviderWatcherMarker>()?;

        fasync::spawn(
            story_watcher_request
                .into_stream()?
                .map_ok(move |request| match request {
                    StoryProviderWatcherRequest::OnChange {
                        story_info,
                        story_state,
                        ..
                    } => {
                        if story_state == StoryState::Stopped {
                            APP.lock()
                                .request_start_story(story_info.id.to_string())
                                .unwrap_or_else(|e| {
                                    eprintln!("error adding story {}: {:?}", story_info.id, e);
                                });
                        }
                    }
                    StoryProviderWatcherRequest::OnDelete { story_id, .. } => {
                        APP.lock()
                            .remove_view_for_story(story_id.to_string())
                            .unwrap_or_else(|e| {
                                eprintln!("error removing story {}: {:?}", story_id, e);
                            });
                    }
                })
                .try_collect::<()>()
                .unwrap_or_else(|e| eprintln!("story watcher error: {:?}", e)),
        );

        let f = self.story_provider.get_stories(Some(story_watcher));
        fasync::spawn(
            f.map_ok(move |r| {
                for story in r {
                    APP.lock()
                        .request_start_story(story.id.to_string())
                        .unwrap_or_else(|e| {
                            eprintln!("error adding view for initial story {}: {:?}", story.id, e);
                        });
                }
            })
            .unwrap_or_else(|e| eprintln!("get_stories error: {:?}", e)),
        );
        Ok(())
    }

    pub fn handle_hot_key(&mut self, event: &KeyboardEvent) -> Result<(), Error> {
        let key_to_use = self.next_story_key();
        self.views[0].lock().handle_hot_key(event, key_to_use)
    }

    pub fn handle_suggestion(&mut self, text: Option<&str>) -> Result<(), Error> {
        let mut view = self.views[0].lock();
        if let Some(text) = text {
            view.handle_suggestion(text)
                .unwrap_or_else(|e| eprintln!("handle_suggestion error: {:?}", e));
        }
        view.remove_ask_box();
        Ok(())
    }
}

fn main() -> Result<(), Error> {
    let mut executor = fasync::Executor::new().context("Error creating executor")?;

    let fut = component::server::ServicesServer::new()
        .add_service((ViewProviderMarker::NAME, move |chan| {
            App::spawn_view_provider_server(chan);
        }))
        .add_service((tiles::ControllerMarker::NAME, move |chan| {
            App::spawn_tiles_server(chan);
        }))
        .add_service((SessionShellMarker::NAME, move |chan| {
            App::spawn_session_shell_server(chan);
        }))
        .start()
        .context("Error starting services server")?;

    executor.run_singlethreaded(fut)?;

    Ok(())
}
