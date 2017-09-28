// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#[derive(Copy, Clone, Debug, PartialEq, PartialOrd)]
pub struct Size {
    pub width: i32,
    pub height: i32,
}

#[allow(dead_code)]
impl Size {
    pub fn add(&self, size: Size) -> Size {
        Size {
            width: self.width + size.width,
            height: self.height + size.height,
        }
    }

    pub fn subtract(&self, size: Size) -> Size {
        Size {
            width: self.width - size.width,
            height: self.height - size.height,
        }
    }
}

#[derive(Copy, Clone, Debug, PartialEq, PartialOrd)]
pub struct Point {
    pub x: i32,
    pub y: i32,
}

#[allow(dead_code)]
impl Point {
    pub fn add(&self, pt: Point) -> Point {
        Point {
            x: self.x + pt.x,
            y: self.y + pt.y,
        }
    }

    pub fn subtract(&self, pt: Point) -> Point {
        Point {
            x: self.x - pt.x,
            y: self.y - pt.y,
        }
    }

    pub fn to_size(&self) -> Size {
        Size {
            width: self.x,
            height: self.y,
        }
    }
}

#[derive(Copy, Clone, Debug, PartialEq, PartialOrd)]
pub struct Rectangle {
    pub origin: Point,
    pub size: Size,
}

#[allow(dead_code)]
impl Rectangle {
    pub fn empty(&self) -> bool {
        self.size.width <= 0 && self.size.height <= 0
    }
}
