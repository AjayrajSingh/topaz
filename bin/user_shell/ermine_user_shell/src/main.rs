// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

use failure::{Error, ResultExt};
use fidl::endpoints::{create_proxy, ClientEnd, RequestStream, ServerEnd, ServiceMarker};
use fidl_fuchsia_developer_tiles as tiles;
use fidl_fuchsia_math::SizeF;
use fidl_fuchsia_modular::{StoryProviderProxy, UserShellContextMarker, UserShellContextProxy};
use fidl_fuchsia_ui_input::{KeyboardEvent, KeyboardEventPhase, MODIFIER_LEFT_CONTROL,
                            MODIFIER_RIGHT_CONTROL};
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

mod view;

use crate::view::{ErmineView, ErmineViewPtr};

pub struct App {
    view_manager: ViewManagerProxy,
    views: Vec<ErmineViewPtr>,
    user_shell_context: UserShellContextProxy,
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
        let user_shell_context = connect_to_service::<UserShellContextMarker>()?;
        let (story_provider, story_provider_end) = create_proxy()?;
        user_shell_context
            .clone()
            .get_story_provider(story_provider_end)?;

        let app = Arc::new(Mutex::new(App {
            view_manager,
            views: vec![],
            user_shell_context,
            story_provider,
            presentation_proxy: None,
            next_key: 1,
        }));
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
                }).unwrap_or_else(|e| eprintln!("error running view_provider server: {:?}", e)),
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

    pub fn setup_keyboard_hack(&mut self) -> Result<(), Error> {
        let (presentation_proxy, presentation_request) = create_proxy()?;
        self.user_shell_context
            .clone()
            .get_presentation(presentation_request)?;
        self.presentation_proxy = Some(presentation_proxy);

        let mut hotkey_event = KeyboardEvent {
            event_time: 0,
            device_id: 0,
            phase: KeyboardEventPhase::Released,
            hid_usage: 0,
            code_point: 0x67,
            modifiers: MODIFIER_LEFT_CONTROL | MODIFIER_RIGHT_CONTROL,
        };
        let (event_listener_client, event_listener_server) = zx::Channel::create()?;
        let event_listener = ClientEnd::new(event_listener_client);
        let event_listener_request =
            ServerEnd::<KeyboardCaptureListenerHackMarker>::new(event_listener_server);

        self.presentation_proxy
            .clone()
            .unwrap()
            .capture_keyboard_event_hack(&mut hotkey_event, event_listener)?;

        fasync::spawn(
            event_listener_request
                .into_stream()
                .unwrap()
                .try_for_each(move |event| match event {
                    KeyboardCaptureListenerHackRequest::OnEvent { .. } => {
                        println!("ermine: hotkey support goes here");
                        futures::future::ready(Ok(()))
                    }
                }).unwrap_or_else(|e| eprintln!("keyboard hack listener error: {:?}", e)),
        );

        Ok(())
    }

    fn next_story_key(&mut self) -> u32 {
        let next_key = self.next_key;
        self.next_key += 1;
        next_key
    }

    pub fn setup_story(
        &mut self, key: u32, story_id: &str, module_name: String, allow_focus: bool,
    ) -> Result<(), Error> {
        self.views[0].lock().setup_story(
            key,
            story_id,
            module_name,
            allow_focus,
            &self.story_provider,
        )?;

        Ok(())
    }

    pub fn add_story(&mut self, module_name: String, allow_focus: bool) -> u32 {
        let key_to_use = self.next_story_key();
        let f = self.story_provider.create_story(None);
        fasync::spawn(
            f.map_ok(move |r| {
                APP.lock()
                    .setup_story(key_to_use, &r, module_name, allow_focus)
                    .unwrap();
            }).unwrap_or_else(|e| eprintln!("create_story error: {:?}", e)),
        );
        key_to_use
    }

    pub fn remove_story(&mut self, key: u32) {
        self.views[0].lock().remove_story(key);
    }

    pub fn list_stories(&self) -> (Vec<u32>, Vec<String>, Vec<SizeF>, Vec<bool>) {
        self.views[0].lock().list_stories()
    }

    pub fn spawn_tiles_server(chan: fasync::Channel) {
        fasync::spawn(
            tiles::ControllerRequestStream::from_channel(chan)
                .try_for_each(move |req| match req {
                    tiles::ControllerRequest::AddTileFromUrl {
                        url,
                        allow_focus,
                        responder,
                        ..
                    } => {
                        let key = APP.lock().add_story(url, allow_focus);
                        fready(responder.send(key))
                    }
                    tiles::ControllerRequest::AddTileFromViewProvider { responder, .. } => {
                        fready(responder.send(0))
                    }
                    tiles::ControllerRequest::RemoveTile { key, .. } => {
                        APP.lock().remove_story(key);
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
                }).unwrap_or_else(|e| eprintln!("error running Tiles controller server: {:?}", e)),
        )
    }
}

fn main() -> Result<(), Error> {
    let mut executor = fasync::Executor::new().context("Error creating executor")?;

    let fut = component::server::ServicesServer::new()
        .add_service((ViewProviderMarker::NAME, move |channel| {
            App::spawn_view_provider_server(channel);
        })).add_service((tiles::ControllerMarker::NAME, move |chan| {
            App::spawn_tiles_server(chan)
        })).start()
        .context("Error starting services server")?;

    executor.run_singlethreaded(fut)?;

    Ok(())
}
