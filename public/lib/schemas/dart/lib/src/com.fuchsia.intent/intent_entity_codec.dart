// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:lib.app.dart/logging.dart';

import '../entity_codec.dart';
import 'intent_entity_data.dart';

const String _kType = 'com.fuchsia.intent';

/// This [EntityCodec] translates Entity source data to and from the structured
/// [IntentEntityData].
class IntentEntityCodec extends EntityCodec<IntentEntityData> {
  /// Create an instance of [IntentEntityCodec].
  IntentEntityCodec()
      : super(
          type: _kType,
          encode: _encode,
          decode: _decode,
        );
}

/// Encodes [IntentEntityData] into a [String].
String _encode(IntentEntityData intent) {
  Map<String, dynamic> data = <String, dynamic>{'parameters': intent.parameters};
  if (intent.action != null) {
    data['action'] = intent.action;
  } else if (intent.handler != null) {
    data['handler'] = intent.handler;
  }
  return json.encode(data);
}

/// Decodes [String] into a structured [IntentEntityData].
IntentEntityData _decode(String data) {
  assert(data != null);
  assert(data.isNotEmpty);

  try {
    Map<String, dynamic> decodedJson = json.decode(data);
    if (!decodedJson.containsKey('action') && !decodedJson.containsKey('handler')) {
      throw new Exception('Invalid IntentEntityData: data does not contain action'
          ' or handler.');
    }

    IntentEntityData entity;
    if (decodedJson.containsKey('action')) {
      entity = new IntentEntityData.fromAction(decodedJson['action']);
    } else {
      entity = new IntentEntityData.fromHandler(decodedJson['handler']);
    }
    entity.parameters.addAll(decodedJson['parameters'].cast<String, String>());
    return entity;
  } on Exception catch (e) {
    log.warning('$_kType entity error when decoding from json string: $json'
        '\nerror: $e');
    rethrow;
  }
}
