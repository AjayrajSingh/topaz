// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show json;

import 'package:lib.app.dart/logging.dart';
import 'package:lib.schemas.dart/entity_codec.dart';

/// Convert list of Strings to a form passable over a Link between
/// modules.
class StringListEntityCodec extends EntityCodec<List<String>> {
  /// Constuctor assigns the proper values to en/decode a the request.
  StringListEntityCodec(String entityType)
      : super(
          type: entityType,
          encode: _encode,
          decode: _decode,
        );

  static String _encode(List<String> data) {
    log.fine('Encode data to json: $data');
    if (data == null) {
      return 'null';
    }
    return json.encode(data);
  }

  static List<String> _decode(Object data) {
    log.fine('Convert to data from json: $data');
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
    dynamic decoded = json.decode(encoded);
    if (decoded == null || decoded is! List) {
      throw const FormatException('Decoding Entity with invalid data');
    }
    // Ensure the type is a List<String>, otherwise you get a List<dynamic>
    return decoded.cast<String>();
  }
}
