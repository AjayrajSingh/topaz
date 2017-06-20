// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#![feature(asm)]

extern crate cairo;

extern crate application_services_service_provider;
extern crate application_services;
extern crate apps_mozart_services_composition;
extern crate apps_mozart_services_input;
extern crate apps_mozart_services_views;
extern crate apps_mozart_services_views_view_token;
#[macro_use]
extern crate fidl;
extern crate magenta;
extern crate mxruntime;

mod application;
mod application_context;
mod base_input_listener;
mod base_view;
mod geometry;
mod service_provider_server;
mod view_provider;

use application_context::{ApplicationContext, ApplicationContextPtr};
use fidl::Server;
use magenta::{Channel, HandleBase};
use mxruntime::{HandleType, get_startup_handle};
use service_provider_server::ServiceProviderServer;

#[cfg(target_arch = "x86_64")]
use std::panic;

/// Produces a proper backtrace on panic by triggering a software breakpoint
/// with a special value in a register that causes it to print a backtrace and
/// then resume execution, which then runs the old panic handler.
#[cfg(target_arch = "x86_64")]
pub fn install_panic_backtrace_hook() {
    let old_hook = panic::take_hook();
    panic::set_hook(Box::new(move |arg| {
        unsafe {
            // constant comes from CRASHLOGGER_RESUME_MAGIC in crashlogger.h
            asm!("mov $$0xee726573756d65ee, %rax; int3" : : : "rax" : "volatile");
        }
        old_hook(arg)
    }));
}

#[cfg(not(target_arch = "x86_64"))]
pub fn install_panic_backtrace_hook() {}

pub fn main() {
    install_panic_backtrace_hook();

    let application_context: ApplicationContextPtr = ApplicationContext::new();
    let startup_handle = get_startup_handle(HandleType::OutgoingServices)
        .expect("couldn't get outgoing services handle");
    let chan = Channel::from_handle(startup_handle);
    let my_server = ServiceProviderServer { application_context: application_context };
    let server_thread = Server::new(my_server, chan).spawn();
    let _ = server_thread.join();
}
