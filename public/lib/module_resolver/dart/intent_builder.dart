// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show json;

import 'package:fidl_modular/fidl.dart';

/// Dart-idiomatic wrapper to create a modular.Intent.
class IntentBuilder {
  final Intent _intent;

  // Creates a new intent builder where the intent's action is set to the
  // provided name.
  IntentBuilder.action(String name)
      : _intent = new Intent(action: new IntentAction(name: name), parameters: <IntentParameter>[]);

  // Creates a new intent builder where the intent's handler is set to the
  // provided handler string.
  IntentBuilder.handler(String handler)
      : _intent = new Intent(action: new IntentAction(name: '', handler: handler), parameters: <IntentParameter>[]);

  // Converts |value| to a JSON object and adds it to the Intent. For typed
  // data, prefer to use addParameterFromEntityReference().
  void addParameter<T>(String name, T value) {
    _addParameter(name, new IntentParameterData.withJson(json.encode(value)));
  }

  // Adds a parameter that containts an entity reference to the intent.
  void addParameterFromEntityReference(String name, String reference) {
    _addParameter(name, new IntentParameterData.withEntityReference(reference));
  }

  // Adds a parameter that containts a Link to the intent.
  void addParameterFromLink(String name, String linkName) {
    _addParameter(name, new IntentParameterData.withLinkName(linkName));
  }

  // The intent being built. 
  Intent get intent => _intent;

  void _addParameterFromIntentParameter(IntentParameter parameter) {
    _intent.parameters.add(parameter);
  }

  void _addParameter(String name, IntentParameterData parameterData) {
    _addParameterFromIntentParameter(new IntentParameter(name: name, data: parameterData));
  }
}
