// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

use application_context::ApplicationContextPtr;
use fidl::Server;
use view_provider::ViewProviderServer;

use application_services::application_services_service_provider::{ServiceProvider,
                                                                  ServiceProvider_Stub};
use zircon::Channel;
use std::io::{self, Write};

pub struct ServiceProviderServer {
    pub application_context: ApplicationContextPtr,
}

impl ServiceProvider for ServiceProviderServer {
    fn connect_to_service(&mut self, service_name: String, channel: Channel) {
        if service_name == "mozart::ViewProvider" {
            let view_provider_server = ViewProviderServer {
                views: Vec::new(),
                application_context: self.application_context.clone(),
            };
            let _ = Server::new(view_provider_server, channel).spawn();
        } else {
            if let Err(e) = write!(io::stderr(), "unknown service name {}\n", service_name) {
                panic!("Error writing error to stdout: {}", e);
            }
        }
    }
}

impl ServiceProvider_Stub for ServiceProviderServer {
    // Use default dispatching, but we could override it here.
}

impl_fidl_stub!(ServiceProviderServer: ServiceProvider_Stub);
