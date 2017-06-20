// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

extern crate cairo;

use std::cmp::min;
use std::sync::mpsc::Receiver;
use std::sync::mpsc::Sender;
use std::sync::mpsc;
use std::thread;

use cairo::ImageSurface;

use geometry::{Point, Size};

pub enum ApplicationEvent {
    Start { size: Size },
    Draw { channel: Sender<Box<[u8]>> },
    MouseButtonDown { which: i32, location: Point },
    MouseButtonUp { which: i32, location: Point },
    MouseButtonMoved { which: i32, location: Point },
}

pub struct Application {
    square_size: Size,
    square_offset: Point,
    center: Point,
    angle: f64,
    tracking: bool,
    pub sender: Sender<ApplicationEvent>,
}

impl Application {
    pub fn run_internal(rx: &Receiver<ApplicationEvent>, tx: &Sender<ApplicationEvent>) {
        let event_result = rx.recv();
        let mut start_size: Size = Size {
            width: 0,
            height: 0,
        };
        match event_result {
            Err(_) => {}
            Ok(event) => {
                match event {
                    ApplicationEvent::Start { size } => {
                        start_size = size;
                    }
                    _ => panic!("Recieved another event before the start event."),
                }
            }
        }
        let mut application = Application::new(start_size, tx);
        application.setup();
        loop {
            let event = rx.recv().expect("internal channel should never close");
            match event {
                ApplicationEvent::Draw { channel } => {
                    let mut image_surface = ImageSurface::create(cairo::Format::ARgb32,
                                                                 start_size.width,
                                                                 start_size.height);
                    {
                        let cairo_context = cairo::Context::new(&image_surface);
                        application.draw(&cairo_context);
                    }
                    let image_data = image_surface.get_data().unwrap();
                    channel.send(image_data.to_vec().into_boxed_slice()).unwrap();
                }
                ApplicationEvent::MouseButtonDown { which, location } => {
                    application.touch_start(which as i32, location);
                }
                ApplicationEvent::MouseButtonUp { which, location } => {
                    application.touch_end(which as i32, location);
                }
                ApplicationEvent::MouseButtonMoved { which, location } => {
                    application.touch_move(which as i32, location);
                }
                _ => (),
            }
        }
    }

    pub fn run() -> Sender<ApplicationEvent> {
        let (tx, rx): (Sender<ApplicationEvent>, Receiver<ApplicationEvent>) = mpsc::channel();
        let tx_internal = tx.clone();
        thread::spawn(move || {
            Application::run_internal(&rx, &tx_internal);
        });
        tx
    }

    pub fn new(size: Size, tx: &Sender<ApplicationEvent>) -> Application {
        let half_height = size.height / 2;
        let half_width = size.width / 2;
        let extent = min(half_width, half_height);
        Application {
            square_size: Size {
                width: extent,
                height: extent,
            },
            square_offset: Point {
                x: half_width - extent / 2,
                y: half_height - extent / 2,
            },
            center: Point {
                x: size.width / 2,
                y: size.height / 2,
            },
            angle: 0.785398,
            tracking: false,
            sender: tx.clone(),
        }
    }

    pub fn setup(&mut self) {}

    pub fn draw(self: &mut Self, context: &cairo::Context) {

        context.set_source_rgba(1.0, 1.0, 1.0, 1.0);
        context.set_font_size(72.0);
        let text = "Touch or click to drag the square";
        let extents = context.text_extents(&text);
        context.move_to(self.center.x as f64 - extents.width / 2.0,
                        20.0 - extents.y_bearing);
        context.show_text(&text);

        context.set_source_rgba(1.0, 0.0, 1.0, 1.0);
        context.translate(self.square_offset.x as f64, self.square_offset.y as f64);
        context.translate((self.square_size.width / 2) as f64,
                          (self.square_size.height / 2) as f64);
        context.rotate(self.angle);
        context.translate(-(self.square_size.width / 2) as f64,
                          -(self.square_size.height / 2) as f64);
        context.rectangle(0.0,
                          0.0,
                          self.square_size.width as f64,
                          self.square_size.height as f64);
        context.fill();
        if !self.tracking {
            self.angle = self.angle + 0.01;
        }
    }

    pub fn touch_start(&mut self, _touch_id: i32, _pt: Point) {
        self.tracking = true;
    }

    pub fn touch_move(&mut self, _touch_id: i32, pt: Point) {
        if self.tracking {
            let y_delta = (self.center.y - pt.y) as f64;
            let x_delta = (self.center.x - pt.x) as f64;
            self.angle = y_delta.atan2(x_delta);
        }
    }

    pub fn touch_end(&mut self, _touch_id: i32, _pt: Point) {
        self.tracking = false;
    }
}
