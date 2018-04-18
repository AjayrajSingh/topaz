// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:lib.logging/logging.dart';

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
  Map<String, Object> data = <String, Object>{'nouns': intent.nouns};
  if (intent.verb != null) {
    data['verb'] = intent.verb;
  } else if (intent.url != null) {
    data['url'] = intent.url;
  }
  return json.encode(data);
}

/// Decodes [String] into a structured [IntentEntityData].
IntentEntityData _decode(String data) {
  assert(data != null);
  assert(data.isNotEmpty);

  try {
    Map<String, dynamic> decodedJson = json.decode(data);
    if (!decodedJson.containsKey('verb') && !decodedJson.containsKey('url')) {
      throw new Exception('Invalid IntentEntityData: data does not contain verb'
          ' or url.');
    }

    IntentEntityData entity;
    if (decodedJson.containsKey('verb')) {
      entity = new IntentEntityData.fromVerb(decodedJson['verb']);
    } else {
      entity = new IntentEntityData.fromUrl(decodedJson['url']);
    }
    entity.nouns.addAll(decodedJson['nouns']);
    return entity;
  } on Exception catch (e) {
    log.warning('$_kType entity error when decoding from json string: $json'
        '\nerror: $e');
    rethrow;
  }
}
