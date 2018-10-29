// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl;

import '../intent_parameter.dart';

/// A [IntentParameterDataTransformer] for IntentParameter objects backed by
/// entity references
class EntityIntentParameterDataTransformer
    implements IntentParameterDataTransformer {
  @override
  Stream<T> createStream<T>(
      fidl.IntentParameterData data, IntentParameterCodec<T> codec) {
    throw Exception('Not implemented yet');
  }

  @override
  Future<T> getValue<T>(
      fidl.IntentParameterData data, IntentParameterCodec<T> codec) {
    throw Exception('Not implemented yet');
  }
}
