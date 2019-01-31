// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#![feature(async_await, await_macro, futures_api)]

use carnelian::{App, AppAssistant, ViewAssistant, ViewAssistantContext, ViewAssistantPtr};
use failure::{Error, ResultExt};
use fidl::encoding::OutOfLine;
use fidl::endpoints::create_endpoints;
use fidl_fuchsia_modular::AppConfig;
use fidl_fuchsia_modular_auth::{Account, IdentityProvider};
use fidl_fuchsia_modular_internal::{SessionmgrMarker, UserContextMarker};
use fidl_fuchsia_ui_gfx::{self as gfx, ColorRgba};
use fidl_fuchsia_ui_viewsv1token::ViewOwnerMarker;
use fuchsia_app::client::{App as LaunchedApp, LaunchOptions, Launcher};
use fuchsia_async as fasync;
use fuchsia_scenic::{Circle, EntityNode, ImportNode, Material, Rectangle, SessionPtr, ShapeNode};
use log::{info, warn};
use parking_lot::Mutex;
use rand::Rng;
use std::collections::BTreeMap;
use std::{any::Any, cell::RefCell};

mod layout;
mod user_context;

use crate::layout::{layout, ChildViewData};
use crate::user_context::UserContext;

struct VoilaAppAssistant {}

impl AppAssistant for VoilaAppAssistant {
    fn setup(&mut self) -> Result<(), Error> {
        Ok(())
    }

    fn create_view_assistant(&mut self, session: &SessionPtr) -> Result<ViewAssistantPtr, Error> {
        Ok(Mutex::new(RefCell::new(Box::new(VoilaViewAssistant {
            background_node: ShapeNode::new(session.clone()),
            circle_node: ShapeNode::new(session.clone()),
            width: 0.0,
            height: 0.0,
            replicas: BTreeMap::new(),
        }))))
    }
}

struct VoilaViewAssistant {
    background_node: ShapeNode,
    circle_node: ShapeNode,
    width: f32,
    height: f32,
    replicas: BTreeMap<u32, ReplicaData>,
}

/// Represents an emulated replica and holds its internal state.
struct ReplicaData {
    #[allow(unused)]
    sessionmgr_app: LaunchedApp,
    view: ChildViewData,
}

impl VoilaViewAssistant {
    fn create_replica(
        &mut self, key: u32, profile_id: &str, url: &str, session: &SessionPtr,
        view_container: &fidl_fuchsia_ui_viewsv1::ViewContainerProxy, import_node: &ImportNode,
    ) -> Result<(), Error> {
        let replica_random_number = rand::thread_rng().gen_range(1, 1000000);
        let replica_id = format!("voila-r{}", replica_random_number.to_string());
        info!("Voila: creating a replica {}", replica_id);

        // Configure disk directory.
        let data_origin = format!("/data/voila/{}", replica_id);
        std::fs::create_dir_all(data_origin.clone())?;
        let mut launch_options = LaunchOptions::new();
        launch_options
            .add_dir_to_namespace("/data".to_string(), std::fs::File::open(data_origin)?)?;

        // Launch an instance of sessionmgr for the replica.
        let app = Launcher::new()?.launch_with_options(url.to_string(), None, launch_options)?;
        let sessionmgr = app.connect_to_service(SessionmgrMarker)?;

        // Set up the emulated account.
        let mut account = Account {
            id: replica_id.clone(),
            identity_provider: IdentityProvider::Dev,
            display_name: replica_id.clone(),
            image_url: "https://example.com".to_string(),
            url: "https://example.com".to_string(),
            profile_id: profile_id.to_string(),
        };

        // Set up shell configs.
        let mut session_shell_config = AppConfig {
            url: "fuchsia-pkg://fuchsia.com/ermine#meta/ermine.cmx".to_string(),
            args: None,
        };
        let mut story_shell_config = AppConfig {
            url: "fuchsia-pkg://fuchsia.com/mondrian#meta/mondrian.cmx".to_string(),
            args: None,
        };

        // Set up views.
        let (view_owner_client, view_owner_server) = create_endpoints::<ViewOwnerMarker>()?;
        let host_node = EntityNode::new(session.clone());
        let host_import_token = host_node.export_as_request();
        import_node.add_child(&host_node);
        let view_data = ChildViewData::new(key, host_node);
        let session_data = ReplicaData {
            sessionmgr_app: app,
            view: view_data,
        };
        self.replicas.insert(key, session_data);
        view_container.add_child(key, view_owner_client, host_import_token)?;

        // Set up UserContext.
        let (user_context_client, user_context_server) = create_endpoints::<UserContextMarker>()?;
        let user_context = UserContext {};
        let user_context_stream = user_context_server.into_stream()?;
        fasync::spawn(
            async move {
                await!(user_context.handle_requests_from_stream(user_context_stream))
                    .unwrap_or_else(|err| {
                        warn!("Error handling UserContext request channel: {:?}", err);
                    })
            },
        );

        sessionmgr
            .initialize(
                Some(OutOfLine(&mut account)),
                &mut session_shell_config,
                &mut story_shell_config,
                None, /* ledger_token_manager */
                None, /* agent_token_manager */
                user_context_client,
                Some(view_owner_server),
            )
            .context("Failed to issue initialize request for sessionmgr")?;
        Ok(())
    }
}

impl ViewAssistant for VoilaViewAssistant {
    fn setup(&mut self, context: &ViewAssistantContext) -> Result<(), Error> {
        context
            .import_node
            .resource()
            .set_event_mask(gfx::METRICS_EVENT_MASK);
        context.import_node.add_child(&self.background_node);
        let material = Material::new(context.session.clone());
        material.set_color(ColorRgba {
            red: 0x00,
            green: 0x00,
            blue: 0xff,
            alpha: 0xff,
        });
        self.background_node.set_material(&material);

        context.import_node.add_child(&self.circle_node);
        let material = Material::new(context.session.clone());
        material.set_color(ColorRgba {
            red: 0xff,
            green: 0x00,
            blue: 0xff,
            alpha: 0xff,
        });
        self.circle_node.set_material(&material);

        let profile_random_number = rand::thread_rng().gen_range(1, 1000000);
        let profile_id = format!("voila-p{}", profile_random_number.to_string());
        self.create_replica(
            1,
            &profile_id,
            "fuchsia-pkg://fuchsia.com/sessionmgr#meta/sessionmgr.cmx",
            context.session,
            context.view_container,
            context.import_node,
        )?;
        self.create_replica(
            2,
            &profile_id,
            "fuchsia-pkg://fuchsia.com/sessionmgr#meta/sessionmgr.cmx",
            context.session,
            context.view_container,
            context.import_node,
        )?;
        Ok(())
    }

    fn update(&mut self, context: &ViewAssistantContext) -> Result<(), Error> {
        self.width = context.width;
        self.height = context.height;

        let center_x = self.width * 0.5;
        let center_y = self.height * 0.5;
        self.background_node.set_shape(&Rectangle::new(
            context.session.clone(),
            self.width,
            self.height,
        ));
        self.background_node
            .set_translation(center_x, center_y, 0.0);

        let circle_radius = self.width.min(self.height) * 0.25;
        self.circle_node
            .set_shape(&Circle::new(context.session.clone(), circle_radius));
        self.circle_node.set_translation(center_x, center_y, 8.0);

        let mut views: Vec<&mut ChildViewData> = self
            .replicas
            .iter_mut()
            .map(|(_key, child_session)| &mut child_session.view)
            .collect();
        layout(&mut views, context.view_container, self.width, self.height)?;
        Ok(())
    }

    fn handle_message(&mut self, _message: &Any) {}
}

fn main() -> Result<(), Error> {
    let assistant = VoilaAppAssistant {};
    App::run(Box::new(assistant))
}
