// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

use failure::Error;
use fidl::encoding::OutOfLine;
use fidl::endpoints::{create_proxy, ClientEnd, ServerEnd, ServiceMarker};
use fidl_fuchsia_math::{InsetF, RectF, SizeF};
use fidl_fuchsia_modular::{Intent, StoryProviderProxy};
use fidl_fuchsia_ui_gfx::{self as gfx, ColorRgba};
use fidl_fuchsia_ui_input::{InputConnectionMarker, InputConnectionProxy, InputListenerMarker,
                            InputListenerRequest};
use fidl_fuchsia_ui_scenic::{SessionListenerMarker, SessionListenerRequest};
use fidl_fuchsia_ui_viewsv1::{CustomFocusBehavior, ViewContainerListenerMarker,
                              ViewContainerListenerRequest, ViewLayout, ViewListenerMarker,
                              ViewListenerRequest, ViewProperties};
use fuchsia_async as fasync;
use fuchsia_scenic::{EntityNode, ImportNode, Material, Rectangle, Session, SessionPtr, ShapeNode};
use fuchsia_zircon::{self as zx, Channel};
use futures::{future::ready as fready, TryFutureExt, TryStreamExt};
use itertools::Itertools;
use parking_lot::Mutex;
use std::collections::BTreeMap;
use std::sync::Arc;

struct ViewData {
    key: u32,
    url: String,
    story_id: String,
    allow_focus: bool,
    bounds: Option<RectF>,
    host_node: EntityNode,
}

impl ViewData {
    pub fn new(
        key: u32, url: String, story_id: String, allow_focus: bool, host_node: EntityNode,
    ) -> ViewData {
        ViewData {
            key: key,
            url: url,
            story_id: story_id,
            bounds: None,
            allow_focus: allow_focus,
            host_node: host_node,
        }
    }
}

pub struct ErmineView {
    // Must keep the view proxy alive or the view goes away.
    _view: fidl_fuchsia_ui_viewsv1::ViewProxy,
    view_container: fidl_fuchsia_ui_viewsv1::ViewContainerProxy,
    input_connection_proxy: InputConnectionProxy,
    session: SessionPtr,
    import_node: ImportNode,
    background_node: ShapeNode,
    container_node: EntityNode,
    views: BTreeMap<u32, ViewData>,
    width: f32,
    height: f32,
}

pub type ErmineViewPtr = Arc<Mutex<ErmineView>>;

impl ErmineView {
    pub fn new(
        view_listener_request: ServerEnd<ViewListenerMarker>,
        view: fidl_fuchsia_ui_viewsv1::ViewProxy, mine: zx::EventPair,
        scenic: fidl_fuchsia_ui_scenic::ScenicProxy,
    ) -> Result<ErmineViewPtr, Error> {
        let (session_listener_client, session_listener_server) = zx::Channel::create()?;
        let session_listener = ClientEnd::new(session_listener_client);

        let (session_proxy, session_request) = create_proxy()?;
        scenic.create_session(session_request, Some(session_listener))?;
        let session = Session::new(session_proxy);

        let (view_container_proxy, view_container_request) = create_proxy()?;

        view.get_container(view_container_request)?;

        let (service_provider_proxy, service_provider_req) = create_proxy()?;

        view.get_service_provider(service_provider_req)?;
        let (input_connection_proxy, input_connection_request) =
            create_proxy::<InputConnectionMarker>()?;
        service_provider_proxy.connect_to_service(
            &InputConnectionMarker::NAME,
            input_connection_request.into_channel(),
        )?;

        let view_controller = ErmineView {
            _view: view,
            view_container: view_container_proxy,
            input_connection_proxy: input_connection_proxy,
            session: session.clone(),
            import_node: ImportNode::new(session.clone(), mine),
            background_node: ShapeNode::new(session.clone()),
            container_node: EntityNode::new(session.clone()),
            views: BTreeMap::new(),
            width: 0.0,
            height: 0.0,
        };

        let view_controller = Arc::new(Mutex::new(view_controller));

        Self::setup_session_listener(&view_controller, session_listener_server);
        Self::setup_view_listener(&view_controller, view_listener_request);
        Self::setup_view_container_listener(&view_controller)?;
        Self::setup_view_input_listener(&view_controller)?;
        Self::finish_setup_scene(&view_controller);

        Ok(view_controller)
    }

    fn setup_session_listener(
        view_controller: &ErmineViewPtr, session_listener_server: zx::Channel,
    ) {
        let session_listener_request =
            ServerEnd::<SessionListenerMarker>::new(session_listener_server);
        let view_controller = view_controller.clone();
        fasync::spawn(
            session_listener_request
                .into_stream()
                .unwrap()
                .map_ok(move |request| match request {
                    SessionListenerRequest::OnScenicEvent { events, .. } => {
                        view_controller.lock().handle_session_events(events)
                    }
                    _ => (),
                })
                .try_collect::<()>()
                .unwrap_or_else(|e| eprintln!("session listener error: {:?}", e)),
        );
    }

    fn setup_view_listener(
        view_controller: &ErmineViewPtr, view_listener_request: ServerEnd<ViewListenerMarker>,
    ) {
        let view_controller = view_controller.clone();
        fasync::spawn(
            view_listener_request
                .into_stream()
                .unwrap()
                .try_for_each(
                    move |ViewListenerRequest::OnPropertiesChanged {
                              properties,
                              responder,
                          }| {
                        view_controller.lock().handle_properies_changed(&properties);
                        fready(responder.send())
                    },
                )
                .unwrap_or_else(|e| eprintln!("view listener error: {:?}", e)),
        );
    }

    fn setup_view_container_listener(view_controller: &ErmineViewPtr) -> Result<(), Error> {
        let view_controller = view_controller.clone();
        let (view_container_listener_client, view_container_listener_server) =
            zx::Channel::create()?;
        let view_container_listener = ClientEnd::new(view_container_listener_client);
        let view_container_listener_request =
            ServerEnd::<ViewContainerListenerMarker>::new(view_container_listener_server);

        view_controller
            .lock()
            .view_container
            .set_listener(Some(view_container_listener))?;

        fasync::spawn(
            view_container_listener_request
                .into_stream()
                .unwrap()
                .try_for_each(move |event| match event {
                    ViewContainerListenerRequest::OnChildAttached { responder, .. } => {
                        view_controller.lock().update();
                        fready(responder.send())
                    }
                    ViewContainerListenerRequest::OnChildUnavailable {
                        responder,
                        child_key,
                    } => {
                        view_controller.lock().remove_story(child_key);
                        fready(responder.send())
                    }
                })
                .unwrap_or_else(|e| eprintln!("view listener error: {:?}", e)),
        );

        Ok(())
    }

    // Currently does nothing but will be hooked up in the future.
    fn setup_view_input_listener(view_controller: &ErmineViewPtr) -> Result<(), Error> {
        let view_controller = view_controller.lock();
        let (event_listener_client, event_listener_server) = zx::Channel::create()?;

        let event_listener = ClientEnd::new(event_listener_client);
        let event_listener_request = ServerEnd::<InputListenerMarker>::new(event_listener_server);

        view_controller
            .input_connection_proxy
            .set_event_listener(Some(event_listener))?;

        fasync::spawn(
            event_listener_request
                .into_stream()
                .unwrap()
                .try_for_each(move |event| match event {
                    InputListenerRequest::OnEvent { responder, .. } => fready(responder.send(true)),
                })
                .unwrap_or_else(|e| eprintln!("view listener error: {:?}", e)),
        );

        Ok(())
    }

    fn finish_setup_scene(view_controller: &ErmineViewPtr) {
        let vc = view_controller.lock();
        vc.setup_scene();
        vc.present();
    }

    fn setup_scene(&self) {
        self.import_node
            .resource()
            .set_event_mask(gfx::METRICS_EVENT_MASK);
        self.import_node.add_child(&self.background_node);
        self.import_node.add_child(&self.container_node);
        let material = Material::new(self.session.clone());
        material.set_color(ColorRgba {
            red: 0x40,
            green: 0x40,
            blue: 0x40,
            alpha: 0x80,
        });
        self.background_node.set_material(&material);
    }

    fn update(&mut self) {
        let center_x = self.width * 0.5;
        let center_y = self.height * 0.5;
        self.background_node.set_shape(&Rectangle::new(
            self.session.clone(),
            self.width,
            self.height,
        ));
        self.background_node
            .set_translation(center_x, center_y, 0.0);
        self.present();
    }

    fn present(&self) {
        fasync::spawn(
            self.session
                .lock()
                .present(0)
                .map_ok(|_| ())
                .unwrap_or_else(|e| eprintln!("present error: {:?}", e)),
        );
    }

    fn handle_session_events(&mut self, events: Vec<fidl_fuchsia_ui_scenic::Event>) {
        events.iter().for_each(|event| match event {
            fidl_fuchsia_ui_scenic::Event::Gfx(gfx::Event::Metrics(_event)) => {
                self.update();
            }
            _ => (),
        });
    }

    fn handle_properies_changed(&mut self, properties: &fidl_fuchsia_ui_viewsv1::ViewProperties) {
        if let Some(ref view_properties) = properties.view_layout {
            self.width = view_properties.size.width;
            self.height = view_properties.size.height;
            self.update();
        }
    }

    fn add_child_view_for_story(
        &mut self, key: u32, url: String, story_id: String, allow_focus: bool, view_owner: Channel,
    ) {
        let host_node = EntityNode::new(self.session.clone());
        let host_import_token = host_node.export_as_request();

        self.view_container
            .add_child(key, ClientEnd::new(view_owner), host_import_token)
            .unwrap();

        self.import_node.add_child(&host_node);
        let view_data = ViewData::new(key, url, story_id, allow_focus, host_node);
        self.views.insert(key, view_data);
        self.update();
        self.layout();
    }

    pub fn display_story(
        &mut self, key: u32, url: String, story_id: &String, story_provider: &StoryProviderProxy,
    ) -> Result<(), Error> {
        let (story_controller, story_controller_end) = create_proxy()?;
        story_provider.get_controller(story_id, story_controller_end)?;
        let (view_owner_client, view_owner_server) = Channel::create()?;
        story_controller.start(ServerEnd::new(view_owner_client))?;
        self.add_child_view_for_story(key, url, story_id.to_string(), true, view_owner_server);
        Ok(())
    }

    pub fn remove_view_for_story(&mut self, story_id: &String) -> Result<(), Error> {
        let result = self
            .views
            .iter()
            .find(|(_key, view)| view.story_id == *story_id);

        if let Some((key, _view)) = result {
            self.remove_story(*key);
        }

        Ok(())
    }

    pub fn setup_story(
        &mut self, key: u32, story_id: &str, module_name: String, allow_focus: bool,
        story_provider: &StoryProviderProxy,
    ) -> Result<(), Error> {
        let (story_controller, story_controller_end) = create_proxy()?;
        story_provider.get_controller(story_id, story_controller_end)?;
        let (view_owner_client, view_owner_server) = Channel::create()?;
        story_controller.start(ServerEnd::new(view_owner_client))?;

        let mut intent = Intent {
            action: Some("view".to_string()),
            handler: Some(module_name.clone()),
            parameters: None,
        };

        story_controller.add_module(None, "root", &mut intent, None)?;

        self.add_child_view_for_story(
            key,
            module_name,
            story_id.to_string(),
            allow_focus,
            view_owner_server,
        );

        Ok(())
    }

    pub fn remove_story(&mut self, key: u32) {
        if self.views.remove(&key).is_some() {
            self.view_container
                .remove_child(key, None)
                .unwrap_or_else(|e| {
                    eprintln!(
                        "view_container.remove_child failed for key {} with {}",
                        key, e
                    );
                });
            self.layout();
            self.update();
        }
    }

    pub fn list_stories(&self) -> (Vec<u32>, Vec<String>, Vec<SizeF>, Vec<bool>) {
        let mut keys = Vec::new();
        let mut urls = Vec::new();
        let mut sizes = Vec::new();
        let mut fs = Vec::new();
        for (key, view) in &self.views {
            let bounds = view.bounds.as_ref().unwrap_or(&RectF {
                x: 0.0,
                y: 0.0,
                width: 0.0,
                height: 0.0,
            });
            keys.push(*key);
            urls.push(view.url.clone());
            sizes.push(SizeF {
                width: bounds.width,
                height: bounds.height,
            });
            fs.push(true);
        }
        (keys, urls, sizes, fs)
    }

    fn inset(rect: &mut RectF, border: f32) {
        let inset = border.min(rect.width / 0.3).min(rect.height / 0.3);
        rect.x += inset;
        rect.y += inset;
        let inset_width = inset * 2.0;
        rect.width = rect.width - inset_width;
        rect.height = rect.height - inset_width;
    }

    pub fn layout(&mut self) {
        if self.views.is_empty() {
            return;
        }

        let num_tiles = self.views.len();

        let columns = (num_tiles as f32).sqrt().ceil() as usize;
        let rows = (columns + num_tiles - 1) / columns;
        let tile_height = (self.height / rows as f32).floor();

        for (row_index, view_chunk) in itertools::enumerate(&self.views.iter_mut().chunks(columns))
        {
            let tiles_in_row = if row_index == rows - 1 && (num_tiles % columns) != 0 {
                num_tiles % columns
            } else {
                columns
            };
            let tile_width = (self.width / tiles_in_row as f32).floor();
            for (column_index, (_key, view)) in view_chunk.enumerate() {
                let mut tile_bounds = RectF {
                    height: tile_height,
                    width: tile_width,
                    x: column_index as f32 * tile_width,
                    y: row_index as f32 * tile_height,
                };
                Self::inset(&mut tile_bounds, 10.0);
                let mut view_properties = ViewProperties {
                    custom_focus_behavior: Some(Box::new(CustomFocusBehavior {
                        allow_focus: view.allow_focus,
                    })),
                    view_layout: Some(Box::new(ViewLayout {
                        inset: InsetF {
                            bottom: 0.0,
                            left: 0.0,
                            right: 0.0,
                            top: 0.0,
                        },
                        size: SizeF {
                            width: tile_bounds.width,
                            height: tile_bounds.height,
                        },
                    })),
                };
                self.view_container
                    .set_child_properties(view.key, Some(OutOfLine(&mut view_properties)))
                    .unwrap();
                view.host_node
                    .set_translation(tile_bounds.x, tile_bounds.y, 0.0);
                view.bounds = Some(tile_bounds);
            }
        }
    }
}
