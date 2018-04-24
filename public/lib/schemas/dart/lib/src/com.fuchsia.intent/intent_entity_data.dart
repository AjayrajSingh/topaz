// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Holds structured data decoded from the Entity's data.
class IntentEntityData {
  /// Create an [IntentEntityData] with a generic action.
  IntentEntityData.fromAction(this.action)
      : assert(action.isNotEmpty),
        handler = null;

  /// Create an [IntentEntityData] with an explicit handler.
  IntentEntityData.fromHandler(this.handler)
      : assert(handler.isNotEmpty),
        action = null;

  /// The action of an Intent
  final String action;

  /// The package name of the module
  final String handler;

  /// The map of parameter names and their data (JSON object)
  final Map<String, String> parameters = <String, String>{};
}
