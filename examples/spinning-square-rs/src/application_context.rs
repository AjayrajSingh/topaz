// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

use application_services::{ApplicationEnvironment, ApplicationEnvironment_Metadata,
                           ApplicationEnvironment_Client, ApplicationEnvironment_Proxy,
                           ApplicationEnvironment_new_Proxy};
use application_services::application_services_service_provider::{ServiceProvider_new_Proxy,
                                                                  ServiceProvider_Server,
                                                                  ServiceProvider_Client};
use apps_mozart_services_views::application_services_service_provider::ServiceProvider_Proxy;
use zircon::{Channel, ChannelOpts, HandleBase};
use mxruntime::{get_service_root, connect_to_environment_service};

use std::sync::{Arc, Mutex};

pub struct ApplicationContext {
    pub environment: ApplicationEnvironment_Proxy,
    pub environment_services: ServiceProvider_Proxy,
}

pub type ApplicationContextPtr = Arc<Mutex<ApplicationContext>>;

impl ApplicationContext {
    pub fn new() -> ApplicationContextPtr {
        let service_root = get_service_root().unwrap();
        let app_env_channel =
            connect_to_environment_service(service_root,
                                           ApplicationEnvironment_Metadata::SERVICE_NAME)
                .unwrap();
        let app_env_client =
            ApplicationEnvironment_Client::from_handle(app_env_channel.into_handle());
        let mut proxy = ApplicationEnvironment_new_Proxy(app_env_client);
        let (p1, p2) = Channel::create(ChannelOpts::Normal).unwrap();
        let service_provider_server = ServiceProvider_Server::from_handle(p1.into_handle());
        proxy.get_services(service_provider_server);
        let service_provider_client = ServiceProvider_Client::from_handle(p2.into_handle());
        let service_provider_proxy = ServiceProvider_new_Proxy(service_provider_client);
        Arc::new(Mutex::new(ApplicationContext {
            environment: proxy,
            environment_services: service_provider_proxy,
        }))
    }
}
