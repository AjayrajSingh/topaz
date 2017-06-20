// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

use application_services_service_provider::{ServiceProvider_new_Proxy, ServiceProvider_Client,
                                            ServiceProvider_Server, ServiceProvider_Proxy,
                                            ServiceProvider};
use apps_mozart_services_composition::{FrameInfo, SceneMetadata, Scene_Client, Scene_new_Proxy,
                                       Scene_Proxy, Scene_Server, Scene, SceneUpdate, NodeOp,
                                       ImageNodeOp, HitTestBehaviorVisibility_Opaque,
                                       HitTestBehavior, Node, ImageResource, Resource};
use apps_mozart_services_composition::apps_mozart_services_buffers::Buffer;
use apps_mozart_services_input::{InputConnection_new_Proxy, InputConnection_Client,
                                 InputListener_Client, InputListener_Metadata,
                                 InputConnection_Metadata, InputConnection};
use apps_mozart_services_composition::apps_mozart_services_geometry::RectF;
use apps_mozart_services_views::{ViewListener_Stub, ViewInvalidation, ViewListener, View_Proxy,
                                 View, ViewListener_Metadata, ViewListener_Client, View_new_Proxy,
                                 View_Client, View_Server, ViewManager_Proxy, ViewManager};
use apps_mozart_services_composition::apps_mozart_services_images::Image;

use fidl::Server;
use magenta::{Channel, ChannelOpts, ClockId, HandleBase, Vmo, VmoOpts, time_get};

use application::Application;
use application::ApplicationEvent;
use base_input_listener::BaseInputListener;
use geometry::Size;

use std::cmp::max;
use std::sync::mpsc::{Sender, Receiver};
use std::sync::mpsc;

pub struct TimePoint {
    pub ticks: i64,
}

impl TimePoint {
    pub fn now() -> TimePoint {
        TimePoint { ticks: time_get(ClockId::Monotonic) as i64 }
    }
}

struct TimeDelta {
    pub delta: i64,
}

impl TimeDelta {}

pub struct FrameTracker {
    frame_count: u64,
    frame_info: FrameInfo,
    presentation_time_delta: TimeDelta,
}

impl FrameTracker {
    pub fn new() -> FrameTracker {
        FrameTracker {
            frame_count: 0,
            frame_info: FrameInfo {
                presentation_time: 0,
                presentation_interval: 0,
                publish_deadline: 0,
                base_time: 0,
            },
            presentation_time_delta: TimeDelta { delta: 0 },
        }
    }

    pub fn update(&mut self, frame_info: FrameInfo, now: TimePoint) {
        let now_ticks = now;
        let old_base_time = self.frame_info.base_time;
        let old_presentation_time = self.frame_info.presentation_time;

        self.frame_info = frame_info;

        // Ensure frame info is sane since it comes from another service.
        if self.frame_info.base_time > now_ticks.ticks {
            self.frame_info.base_time = now_ticks.ticks;
        }

        if self.frame_info.publish_deadline < self.frame_info.base_time {
            self.frame_info.publish_deadline = self.frame_info.base_time;
        }

        // Compensate for significant lag by adjusting the base time if needed
        // to step past skipped frames.
        let lag = now_ticks.ticks - self.frame_info.base_time;
        if self.frame_info.presentation_interval > 0 &&
           lag >= self.frame_info.presentation_interval as i64 {
            let offset = lag % self.frame_info.presentation_interval as i64;
            let adjustment = now_ticks.ticks - offset - self.frame_info.base_time;
            self.frame_info.base_time = now_ticks.ticks - offset;
            self.frame_info.publish_deadline += adjustment;
            self.frame_info.presentation_time += adjustment;
        }

        // Ensure monotonicity.
        self.frame_count = self.frame_count.wrapping_add(1);

        self.frame_info.base_time = max(self.frame_info.base_time, old_base_time);
        self.frame_info.presentation_time = max(self.frame_info.presentation_time,
                                                old_presentation_time);

        self.presentation_time_delta =
            TimeDelta { delta: self.frame_info.base_time - old_base_time }
    }
}

pub struct BaseView {
    pub view: View_Proxy,
    pub scene: Scene_Proxy,
    pub scene_version: u32,
    pub frame_tracker: FrameTracker,
    pub service_provider_proxy: ServiceProvider_Proxy,
    pub channel: Option<Sender<ApplicationEvent>>,
    pub size: Size,
}

impl BaseView {
    pub fn create_view(view_manager_proxy: &mut ViewManager_Proxy,
                       view_owner: ::apps_mozart_services_views_view_token::ViewOwner_Server)
                       -> (View_Proxy, Channel) {
        let (v1, v2) = Channel::create(ChannelOpts::Normal).unwrap();
        let view_server = View_Server::from_handle(v2.into_handle());
        let view_client = View_Client::from_handle(v1.into_handle());
        let view_proxy = View_new_Proxy(view_client);
        let (vl1, vl2) = Channel::create(ChannelOpts::Normal).unwrap();
        let view_listener_client = ViewListener_Client::from_handle(vl1.into_handle());
        let view_listener_client_ptr = ::fidl::InterfacePtr {
            inner: view_listener_client,
            version: ViewListener_Metadata::VERSION,
        };
        view_manager_proxy.create_view(view_server,
                                       view_owner,
                                       view_listener_client_ptr,
                                       Some("Rust Spinning Square".to_string()));
        (view_proxy, vl2)
    }

    pub fn create_scene(view_proxy: &mut View_Proxy) -> Scene_Proxy {
        let (s1, s2) = Channel::create(ChannelOpts::Normal).unwrap();
        let scene_server = Scene_Server::from_handle(s2.into_handle());
        view_proxy.create_scene(scene_server);
        let scene_client = Scene_Client::from_handle(s1.into_handle());
        Scene_new_Proxy(scene_client)
    }

    pub fn create_view_service_provider_proxy(view_proxy: &mut View_Proxy)
                                              -> ServiceProvider_Proxy {
        let (i1, i2) = Channel::create(ChannelOpts::Normal).unwrap();
        let service_provider_server = ServiceProvider_Server::from_handle(i2.into_handle());
        let service_provider_client = ServiceProvider_Client::from_handle(i1.into_handle());
        let service_provider_proxy = ServiceProvider_new_Proxy(service_provider_client);
        view_proxy.get_service_provider(service_provider_server);
        service_provider_proxy
    }

    fn create_scene_metadata(&self) -> SceneMetadata {
        SceneMetadata {
            version: self.scene_version,
            presentation_time: self.frame_tracker.frame_info.presentation_time,
        }
    }

    pub fn create_input_listener(&mut self) {
        let (i1, i2) = Channel::create(ChannelOpts::Normal).unwrap();
        self.service_provider_proxy
            .connect_to_service(InputConnection_Metadata::SERVICE_NAME.to_string(), i2);
        let input_connection_client = InputConnection_Client::from_handle(i1.into_handle());
        let mut input_connection_proxy = InputConnection_new_Proxy(input_connection_client);

        let (il1, il2) = Channel::create(ChannelOpts::Normal).unwrap();
        let input_listener_client = InputListener_Client::from_handle(il1.into_handle());
        let input_listener_client_ptr = ::fidl::InterfacePtr {
            inner: input_listener_client,
            version: InputListener_Metadata::VERSION,
        };

        input_connection_proxy.set_event_listener(Some(input_listener_client_ptr));
        let channel_option = &self.channel.as_ref();
        let orig_channel_ref = channel_option.unwrap();
        let new_channel = orig_channel_ref.clone();
        let _ = Server::new(BaseInputListener {
                                proxy: input_connection_proxy,
                                channel: new_channel,
                            },
                            il2)
            .spawn();
    }
}

impl ViewListener for BaseView {
    fn on_invalidation(&mut self,
                       invalidation: ViewInvalidation)
                       -> ::fidl::Future<(), ::fidl::Error> {
        if let Some(properties) = invalidation.properties {
            if let Some(view_layout) = properties.view_layout {
                if self.channel.is_none() {
                    self.size = Size {
                        width: view_layout.size.width,
                        height: view_layout.size.height,
                    };
                    let tx = Application::run();
                    tx.send(ApplicationEvent::Start {
                            size: Size {
                                width: view_layout.size.width,
                                height: view_layout.size.height,
                            },
                        })
                        .unwrap();
                    self.channel = Some(tx);
                    self.create_input_listener();

                }
            }
        }

        if let Some(ref channel) = self.channel {
            self.frame_tracker.update(invalidation.frame_info, TimePoint::now());
            self.scene_version = invalidation.scene_version;
            let (buffer_tx, buffer_rx): (Sender<Box<[u8]>>, Receiver<Box<[u8]>>) = mpsc::channel();
            channel.send(ApplicationEvent::Draw { channel: buffer_tx })
                .unwrap();
            let rendered_buffer = buffer_rx.recv()
                .expect("unexpected error receiving a rendered buffer");
            let vmo = Vmo::create((self.size.width * self.size.height * 4) as u64,
                                  VmoOpts::Default)
                .unwrap();
            vmo.write(&rendered_buffer, 0).unwrap();
            let buffer = Buffer {
                vmo: vmo,
                fence: None,
                retention: None,
                memory_type: 0,
            };
            let image = Image {
                size: ::apps_mozart_services_views::apps_mozart_services_geometry::Size {
                    width: self.size.width,
                    height: self.size.height,
                },
                stride: (self.size.width * 4) as u32,
                offset: 0,
                pixel_format: 0,
                alpha_format: 0,
                color_space: 0,
                buffer: buffer,
            };
            let image_resource = ImageResource { image: image };
            let content_resource = Resource::Image(Box::new(image_resource));
            let mut resources = ::std::collections::HashMap::new();
            resources.insert(1, Some(Box::new(content_resource)));
            let mut nodes = ::std::collections::HashMap::new();
            let root_node = Node {
                content_transform: None,
                content_clip: None,
                combinator: 0,
                hit_test_behavior: Some(Box::new(HitTestBehavior {
                    visibility: HitTestBehaviorVisibility_Opaque,
                    prune: false,
                    hit_rect: Some(Box::new(RectF {
                        height: self.size.height as f32,
                        width: self.size.width as f32,
                        x: 0.0,
                        y: 0.0,
                    })),
                })),
                child_node_ids: None,
                op: Some(Box::new(NodeOp::Image(Box::new(ImageNodeOp {
                    content_rect: RectF {
                        height: self.size.height as f32,
                        width: self.size.width as f32,
                        x: 0.0,
                        y: 0.0,
                    },
                    image_rect: None,
                    image_resource_id: 1,
                    blend: None,
                })))),
            };
            nodes.insert(0, Some(Box::new(root_node)));
            let update = SceneUpdate {
                clear_resources: false,
                clear_nodes: false,
                resources: Some(resources),
                nodes: Some(nodes),
            };
            self.scene.update(update);
            let metadata = Some(Box::new(self.create_scene_metadata()));
            self.scene.publish(metadata);
            self.view.invalidate();
        }

        ::fidl::Future::Ok(())
    }
}

impl ViewListener_Stub for BaseView {}

impl_fidl_stub!(BaseView: ViewListener_Stub);
