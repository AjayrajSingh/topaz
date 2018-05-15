// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show json;

import 'package:lib.app.dart/logging.dart';
import 'package:lib.schemas.dart/entity_codec.dart';

const String _kCaptionsEntityUri = 'com.fuchsia.captions';

// TODO MS-1308 Move to public entities location

/// Convert a list of captions to a form passable over a Link between processes.
class CaptionsEntityCodec extends EntityCodec<List<String>> {
  /// Constuctor assigns the proper values to en/decode a list of captions.
  CaptionsEntityCodec()
      : super(
          type: _kCaptionsEntityUri,
          encode: _encode,
          decode: _decode,
        );

  static String _encode(List<String> captions) {
    log.fine('Convert captions to json: $captions');
    if (captions == null || captions.isEmpty) {
      return 'null';
    }
    return json.encode(captions);
  }

  static List<String> _decode(Object data) {
    log.fine('Convert to list of captions from json: $data');
    if (data == null) {
      return null;
    }
    if (data is! String) {
      throw const FormatException('Decoding Entity with unsupported type');
    }
    String encoded = data;
    if (encoded.isEmpty) {
      throw const FormatException('Decoding Entity with empty string');
    }
    if (encoded == 'null') {
      return null;
    }
    Object decoded = json.decode(encoded);
    if (decoded == null || decoded is! List) {
      throw const FormatException('Decoding Entity with invalid data');
    }
    List<Object> list = decoded;
    for (Object obj in list) {
      if (obj is! String) {
        throw const FormatException('Captions contained non-String data');
      }
    }
    return list;
  }
}
