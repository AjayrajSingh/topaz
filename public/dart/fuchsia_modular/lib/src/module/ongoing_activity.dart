// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

//ignore_for_file: one_member_abstracts

/// An [OngoingActivity] is an object which allows modules to indicate that they
/// are performing some form of ongoing activity. The system can take this
/// information into account when determining how to manage power. For example,
/// if the module indicates that it is playing a video the system will prevent
/// the display from dimming when not in use.
///
/// Modules should keep a reference to this object while they are perfoming
/// their ongoing activity. When the ongoing activity ends the module must call
/// [#done].
abstract class OngoingActivity {
  /// Calling this method will signal to the framework that the module is done
  /// with the ongoing activity.
  void done();
}
