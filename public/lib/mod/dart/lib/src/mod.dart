// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

/// The simplest way to interface with Fuchsia's Modular system.
class Mod {
  static final Mod _mod = new Mod._internal();
  final Completer<Mod> _initialize = new Completer<Mod>();

  /// The Factory constructor returning the singleton Mod instance.
  ///
  /// Note: a singleton prevents multiple impls of Module and Lifecycle from
  /// being served to the Framework and fighting over who is managing the
  /// Module's internal state.
  ///
  /// Example
  ///
  ///     var Mod mod = Mod();
  ///
  factory Mod() {
    return _mod;
  }

  Mod._internal();

  /// Initialize the mod.
  ///
  /// This method starts the mod by calling into FIDL APIs provided by Modular and
  /// serving impls of Module and Lifecycle. After registering the services as
  /// available, the internal async state management awaits Module#initialize
  /// to be called by Modular signaling a successful startup. And kicks off a series
  /// of client initializations required for making any other calls into Fuchsia.
  ///
  /// This process is async by nature, and can error. Be sure to add error handlers
  /// to all async calls.
  ///
  /// Note: this method can be called multiple times in a row without side effects.
  /// Any call after the first one will resolve with the orginial future.
  Future<Mod> initialize() {
    if (_initialize.isCompleted) {
      return _initialize.future;
    }

    //...

    return _initialize.future;
  }
}
