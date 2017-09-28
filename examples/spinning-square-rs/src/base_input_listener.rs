// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#![allow(non_snake_case,non_upper_case_globals)]

use apps_mozart_services_input::{InputConnection_Proxy, InputListener_Stub, InputListener,
                                 InputEvent};
use apps_mozart_services_input::{PointerEventPhase_Down, PointerEventPhase_Move,
                                 PointerEventPhase_Up};

use std::sync::mpsc::Sender;

use application::ApplicationEvent;
use geometry::Point;

pub struct BaseInputListener {
    pub proxy: InputConnection_Proxy,
    pub channel: Sender<ApplicationEvent>,
}

impl InputListener_Stub for BaseInputListener {}

impl InputListener for BaseInputListener {
    fn on_event(&mut self,
                event: ::apps_mozart_services_input::InputEvent)
                -> ::fidl::Future<bool, ::fidl::Error> {
        match event {
            InputEvent::Keyboard(keyboard_event) => {
                if keyboard_event.hid_usage == 0x14 {
                    ::std::process::exit(0);
                }
            }
            InputEvent::Pointer(pointer_event) => {
                let location = Point {
                    x: pointer_event.x as i32,
                    y: pointer_event.y as i32,
                };
                let which = pointer_event.pointer_id as i32;
                match pointer_event.phase {
                    PointerEventPhase_Down => {
                        self.channel
                            .send(ApplicationEvent::MouseButtonDown {
                                which: which,
                                location: location,
                            })
                            .unwrap();
                    }
                    PointerEventPhase_Move => {
                        self.channel
                            .send(ApplicationEvent::MouseButtonMoved {
                                which: which,
                                location: location,
                            })
                            .unwrap();
                    }
                    PointerEventPhase_Up => {
                        self.channel
                            .send(ApplicationEvent::MouseButtonUp {
                                which: which,
                                location: location,
                            })
                            .unwrap();
                    }
                    _ => (),
                }
            }
            _ => (),
        }
        ::fidl::Future::Ok(true)
    }
}


impl_fidl_stub!(BaseInputListener: InputListener_Stub);
