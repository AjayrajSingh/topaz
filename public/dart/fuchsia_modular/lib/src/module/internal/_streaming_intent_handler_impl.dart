// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fuchsia_modular/lifecycle.dart';

import '../intent.dart';
import '../streaming_intent_handler.dart';

/// The [StreamingIntentHandlerImpl] class is a concrete implementation of the
/// [StreamingIntentHandler].
class StreamingIntentHandlerImpl implements StreamingIntentHandler {
  final _streamController = StreamController<Intent>();

  /// The concrete implementation of [StreamingIntentHandler]. This class
  /// requires a [Lifecycle] object so it can close any streams on terminate.
  StreamingIntentHandlerImpl({
    Lifecycle lifecycle,
  }) {
    (lifecycle ?? Lifecycle()).addTerminateListener(_streamController.close);
  }

  @override
  Stream<Intent> get stream => _streamController.stream;

  @override
  void handleIntent(Intent intent) => _streamController.add(intent);
}
