// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Mode the video player should be in on the device
enum DisplayMode {
  /// Local large (tablet) video mode
  localLarge,

  /// Local small (phone) video mode
  localSmall,

  /// Remote control mode
  remoteControl,

  /// Immersive (a.k.a full-screen, presentation) mode
  immersive,

  /// Standby (ready-to-be-casted-on) mode
  standby,
}

/// Default display mode
const DisplayMode kDefaultDisplayMode = DisplayMode.localLarge;

/// Duration to animate play controls showing/hiding
const Duration kPlayControlsAnimationTime = const Duration(milliseconds: 200);
