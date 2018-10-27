// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl;

import '../intent.dart';
import '../intent_parameter.dart';
import '../module_state_exception.dart';
import '_entity_intent_parameter_data_transformer.dart';

/// Converts the supplied [fidl.IntentParameter] into an [IntentParameter]
/// object. This method will throw a [ModuleStateException] if the parameter
/// data type is not supported.
///
/// Currently, the entityReference is the only supported type.
IntentParameter convertFidlIntentParameterToIntentParameter(
    fidl.IntentParameter fidlIntentParameter) {
  return IntentParameter(
    name: fidlIntentParameter.name,
    data: fidlIntentParameter.data,
    dataTransformer: _transformerForDataTag(fidlIntentParameter.data.tag),
  );
}

/// Converts the [fidlIntent] to an [Intent] object.
Intent convertFidlIntentToIntent(fidl.Intent fidlIntent) {
  if (fidlIntent == null) {
    throw Exception('fidlIntent must not be null in convertFidlIntentToIntent');
  }

  Intent intent = Intent(
    action: fidlIntent.action,
    handler: fidlIntent.handler,
  );

  // We shouldn't have null fidl intent parameters but in the case that we
  // do we avoid adding them as it will cause a crash.
  if (fidlIntent.parameters != null) {
    intent.parameters.addAll(fidlIntent.parameters);
  }

  return intent;
}

IntentParameterDataTransformer _transformerForDataTag(
    fidl.IntentParameterDataTag tag) {
  switch (tag) {
    case fidl.IntentParameterDataTag.entityReference:
      return EntityIntentParameterDataTransformer();
    default:
      throw ModuleStateException(
          'The data of type $tag is not supported at this time');
  }
}
