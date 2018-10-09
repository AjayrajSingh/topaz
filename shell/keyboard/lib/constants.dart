// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The corner radius of the keyboard and its border.
const double cornerRadius = 24.0;

/// The width of the border surrounding the keyboard.
const double borderWidth = 6.0;

/// The height of a key in the keyboard.
const double keyHeight = 44.0;

/// The total height of the keyboard.
///
/// 4 rows of buttons + the border around the keyboard.
const double keyboardHeight = borderWidth + (4 * keyHeight);
