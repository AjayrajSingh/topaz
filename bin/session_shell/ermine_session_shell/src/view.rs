// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

use crate::ask_box::AskBox;
use failure::{Error, ResultExt};
use fidl::encoding::OutOfLine;
use fidl::endpoints::{create_proxy, ClientEnd, ServerEnd};
use fidl_fuchsia_math::{InsetF, RectF, SizeF};
use fidl_fuchsia_modular::{
    AddMod, Intent, PuppetMasterMarker, PuppetMasterProxy, StoryCommand, StoryPuppetMasterProxy,
    SurfaceArrangement, SurfaceDependency, SurfaceRelation,
};
use fidl_fuchsia_ui_gfx::{self as gfx, ColorRgba};
use fidl_fuchsia_ui_input::KeyboardEvent;
use fidl_fuchsia_ui_scenic::{SessionListenerMarker, SessionListenerRequest};
use fidl_fuchsia_ui_viewsv1::{
    CustomFocusBehavior, ViewContainerListenerMarker, ViewContainerListenerRequest, ViewLayout,
    ViewListenerMarker, ViewListenerRequest, ViewProperties,
};
use fuchsia_app::client::connect_to_service;
use fuchsia_async as fasync;
use fuchsia_scenic::{EntityNode, ImportNode, Material, Rectangle, Session, SessionPtr, ShapeNode};
use fuchsia_zircon as zx;
use futures::{future::ready as fready, TryFutureExt, TryStreamExt};
use itertools::Itertools;
use parking_lot::Mutex;
use std::collections::BTreeMap;
use std::sync::Arc;
use std::time::SystemTime;

fn random_story_name() -> String {
    let secs = match SystemTime::now().duration_since(SystemTime::UNIX_EPOCH) {
        Ok(n) => n.as_secs(),
        Err(_) => panic!("SystemTime before UNIX EPOCH!"),
    };
    format!("ermine-story-{}", secs)
}

fn random_mod_name() -> String {
    let secs = match SystemTime::now().duration_since(SystemTime::UNIX_EPOCH) {
        Ok(n) => n.as_secs(),
        Err(_) => panic!("SystemTime before UNIX EPOCH!"),
    };
    format!("ermine-mod-{}", secs)
}

fn inset(rect: &mut RectF, border: f32) {
    let inset = border.min(rect.width / 0.3).min(rect.height / 0.3);
    rect.x += inset;
    rect.y += inset;
    let inset_width = inset * 2.0;
    rect.width = rect.width - inset_width;
    rect.height = rect.height - inset_width;
}

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
    puppet_master: PuppetMasterProxy,
    story_puppet_masters: BTreeMap<String, StoryPuppetMasterProxy>,
    view_container: fidl_fuchsia_ui_viewsv1::ViewContainerProxy,
    session: SessionPtr,
    import_node: ImportNode,
    background_node: ShapeNode,
    container_node: EntityNode,
    views: BTreeMap<u32, ViewData>,
    width: f32,
    height: f32,
    ask_box: Option<AskBox>,
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

        let puppet_master = connect_to_service::<PuppetMasterMarker>()?;

        let view_controller = ErmineView {
            _view: view,
            puppet_master,
            story_puppet_masters: BTreeMap::new(),
            view_container: view_container_proxy,
            session: session.clone(),
            import_node: ImportNode::new(session.clone(), mine),
            background_node: ShapeNode::new(session.clone()),
            container_node: EntityNode::new(session.clone()),
            views: BTreeMap::new(),
            width: 0.0,
            height: 0.0,
            ask_box: None,
        };

        let view_controller = Arc::new(Mutex::new(view_controller));

        Self::setup_session_listener(&view_controller, session_listener_server)?;
        Self::setup_view_listener(&view_controller, view_listener_request)?;
        Self::setup_view_container_listener(&view_controller)?;
        Self::finish_setup_scene(&view_controller);

        Ok(view_controller)
    }

    fn setup_session_listener(
        view_controller: &ErmineViewPtr, session_listener_server: zx::Channel,
    ) -> Result<(), Error> {
        let session_listener_request =
            ServerEnd::<SessionListenerMarker>::new(session_listener_server);
        let view_controller = view_controller.clone();
        fasync::spawn(
            session_listener_request
                .into_stream()?
                .map_ok(move |request| match request {
                    SessionListenerRequest::OnScenicEvent { events, .. } => {
                        view_controller.lock().handle_session_events(events)
                    }
                    _ => (),
                })
                .try_collect::<()>()
                .unwrap_or_else(|e| eprintln!("session listener error: {:?}", e)),
        );
        Ok(())
    }

    fn setup_view_listener(
        view_controller: &ErmineViewPtr, view_listener_request: ServerEnd<ViewListenerMarker>,
    ) -> Result<(), Error> {
        let view_controller = view_controller.clone();
        fasync::spawn(
            view_listener_request
                .into_stream()?
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
        Ok(())
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
                .into_stream()?
                .try_for_each(move |event| match event {
                    ViewContainerListenerRequest::OnChildAttached { responder, .. } => {
                        view_controller.lock().update();
                        fready(responder.send())
                    }
                    ViewContainerListenerRequest::OnChildUnavailable {
                        responder,
                        child_key,
                    } => {
                        view_controller
                            .lock()
                            .remove_story(child_key)
                            .unwrap_or_else(|e| eprintln!("remove_story error: {:?}", e));
                        fready(responder.send())
                    }
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
            red: 0xb3,
            green: 0x1b,
            blue: 0x1b,
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

    pub fn add_child_view_for_story_attach(
        &mut self, key: u32, story_id: String, view_holder_token: zx::EventPair,
    ) -> Result<(), Error> {
        let host_node = EntityNode::new(self.session.clone());
        let host_import_token = host_node.export_as_request();

        self.view_container
            .add_child2(key, view_holder_token, host_import_token)?;

        self.import_node.add_child(&host_node);
        let view_data = ViewData::new(key, "".to_string(), story_id, true, host_node);
        self.views.insert(key, view_data);
        self.update();
        self.layout()?;
        Ok(())
    }

    pub fn remove_view_for_story(&mut self, story_id: &String) -> Result<(), Error> {
        let result = self
            .views
            .iter()
            .find(|(_key, view)| view.story_id == *story_id);

        if let Some((key, _view)) = result {
            self.remove_story(*key)?;
        }

        Ok(())
    }

    pub fn remove_story(&mut self, key: u32) -> Result<(), Error> {
        if self.views.remove(&key).is_some() {
            self.view_container
                .remove_child(key, None)
                .unwrap_or_else(|e| {
                    eprintln!(
                        "view_container.remove_child failed for key {} with {}",
                        key, e
                    );
                });
            self.layout()?;
            self.update();
        }
        Ok(())
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

    pub fn handle_hot_key(&mut self, event: &KeyboardEvent, key_to_use: u32) -> Result<(), Error> {
        if event.code_point == 0x20 {
            if let Some(ask_box) = self.ask_box.as_mut() {
                ask_box.focus(&self.view_container)?;
            } else {
                self.ask_box = Some(AskBox::new(
                    key_to_use,
                    &self.session,
                    &self.view_container,
                    &self.import_node,
                )?);
                self.update();
                self.layout()?;
            }
        }
        Ok(())
    }

    pub fn remove_ask_box(&mut self) {
        if let Some(mut ask_box) = self.ask_box.take() {
            ask_box
                .remove(&self.view_container)
                .unwrap_or_else(|e| eprintln!("ask_box.remove error: {:?}", e));
        }
    }

    pub fn handle_suggestion(&mut self, text: &str) -> Result<(), Error> {
        let story_name = random_story_name();
        let package = format!("fuchsia-pkg://fuchsia.com/{}#meta/{}.cmx", text, text);
        let (story_puppet_master, story_puppet_master_end) =
            create_proxy().context("handle_suggestion control_story")?;
        self.puppet_master
            .control_story(&story_name, story_puppet_master_end)?;
        let mut commands = [StoryCommand::AddMod(AddMod {
            mod_name: vec![random_mod_name()],
            intent: Intent {
                action: None,
                handler: Some(package),
                parameters: None,
            },
            surface_parent_mod_name: None,
            surface_relation: SurfaceRelation {
                arrangement: SurfaceArrangement::None,
                dependency: SurfaceDependency::None,
                emphasis: 1.0,
            },
        })];
        story_puppet_master
            .enqueue(&mut commands.iter_mut())
            .context("handle_suggestion story_puppet_master.enqueue")?;
        let f = story_puppet_master.execute();
        fasync::spawn(
            f.map_ok(move |_| {})
                .unwrap_or_else(|e| eprintln!("puppetmaster error: {:?}", e)),
        );
        self.story_puppet_masters
            .insert(story_name, story_puppet_master);

        Ok(())
    }

    pub fn layout(&mut self) -> Result<(), Error> {
        if !self.views.is_empty() {
            let num_tiles = self.views.len();

            let columns = (num_tiles as f32).sqrt().ceil() as usize;
            let rows = (columns + num_tiles - 1) / columns;
            let tile_height = (self.height / rows as f32).floor();

            for (row_index, view_chunk) in self
                .views
                .iter_mut()
                .chunks(columns)
                .into_iter()
                .enumerate()
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
                    inset(&mut tile_bounds, 10.0);
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
                        .set_child_properties(view.key, Some(OutOfLine(&mut view_properties)))?;
                    view.host_node
                        .set_translation(tile_bounds.x, tile_bounds.y, 0.0);
                    view.bounds = Some(tile_bounds);
                }
            }
        }

        if let Some(ask_box) = self.ask_box.as_ref() {
            ask_box.layout(&self.view_container, self.width, self.height)?;
        }

        Ok(())
    }
}
