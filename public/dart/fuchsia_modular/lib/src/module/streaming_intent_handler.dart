// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fuchsia_modular/lifecycle.dart';

import 'intent.dart';
import 'intent_handler.dart';
import 'internal/_streaming_intent_handler_impl.dart';

/// The [StreamingIntentHandler] class is an implementation of the
/// [IntentHandler] which can be registered with a module and then used
/// to respond to incoming intents.
abstract class StreamingIntentHandler extends IntentHandler {
  /// Returns an instance of the [StreamingIntentHandler].
  factory StreamingIntentHandler() {
    return StreamingIntentHandlerImpl(lifecycle: Lifecycle());
  }

  /// Returns a stream which will receive all handled [Intent]s.
  ///
  /// This stream will be a single subscription stream.
  Stream<Intent> get stream;
}
