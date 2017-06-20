// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

use application_context::ApplicationContextPtr;
use application_services::application_services_service_provider::{ServiceProvider_Server,
                                                                  ServiceProvider};
use apps_mozart_services_views::{ViewProvider_Stub, ViewProvider, View_Proxy, ViewManager_Client,
                                 ViewManager_new_Proxy};
use fidl::Server;
use magenta::{Channel, ChannelOpts, HandleBase};

use base_view::BaseView;
use base_view::FrameTracker;
use geometry::Size;

pub struct ViewProviderServer {
    pub views: Vec<View_Proxy>,
    pub application_context: ApplicationContextPtr,
}

impl ViewProvider for ViewProviderServer {
    fn create_view(&mut self,
                   view_owner: ::apps_mozart_services_views_view_token::ViewOwner_Server,
                   _services: Option<ServiceProvider_Server>) {
        let (s1, s2) = Channel::create(ChannelOpts::Normal).unwrap();
        self.application_context
            .lock()
            .unwrap()
            .environment_services
            .connect_to_service("mozart::ViewManager".to_string(), s2);
        let view_manager_client = ViewManager_Client::from_handle(s1.into_handle());
        let mut view_manager_proxy = ViewManager_new_Proxy(view_manager_client);
        let (mut view_proxy, vl2) = BaseView::create_view(&mut view_manager_proxy, view_owner);
        let view_service_provider_proxy =
            BaseView::create_view_service_provider_proxy(&mut view_proxy);
        let scene_proxy = BaseView::create_scene(&mut view_proxy);
        let base_view = BaseView {
            view: view_proxy,
            scene: scene_proxy,
            frame_tracker: FrameTracker::new(),
            scene_version: 0,
            service_provider_proxy: view_service_provider_proxy,
            channel: None,
            size: Size {
                width: 0,
                height: 0,
            },
        };
        let _ = Server::new(base_view, vl2).spawn();
    }
}

impl ViewProvider_Stub for ViewProviderServer {
    // Use default dispatching, but we could override it here.
}
impl_fidl_stub!(ViewProviderServer: ViewProvider_Stub);
