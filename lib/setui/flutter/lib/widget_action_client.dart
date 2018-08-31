// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib_setui_common/action.dart';

enum State { started, finished }

/// Base definition for a widget-based action.
abstract class WidgetActionClient {
  State _state;

  /// The result helper to use for relaying results back
  final ActionResultSender actionResultSender;

  WidgetActionClient(this.actionResultSender);

  /// The title to be displayed
  String get title => null;

  /// Invoked to generate the root view.
  Widget build(BuildContext context);

  State get state => _state;

  set state(State state) {
    _state = state;
    onStateChanged(state);
  }

  void onStateChanged(State state) {}
}
