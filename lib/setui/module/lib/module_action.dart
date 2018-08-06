// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A PODO to hold parsed module action information.
class ModuleAction {
  /// The name of the action as specified in the roster.
  final String name;

  /// The module intent verb.
  final String verb;

  /// The package that contains the module.
  final String handler;

  ModuleAction(this.name, this.verb, this.handler);
}
