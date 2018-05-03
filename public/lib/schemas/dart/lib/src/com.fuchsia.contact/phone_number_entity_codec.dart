// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:lib.app.dart/logging.dart';

import '../../com.fuchsia.contact.dart';
import '../entity_codec.dart';

const String _kType = 'com.fuchsia.contact.phone';

/// The [EntityCodec] that translates the [PhoneNumberEntityData].
class PhoneNumberEntityCodec extends EntityCodec<PhoneNumberEntityData> {
  /// Constructor
  PhoneNumberEntityCodec()
      : super(
          type: _kType,
          encode: _encode,
          decode: _decode,
        );
}

/// Encodes [PhoneNumberEntityData] into a [String].
String _encode(PhoneNumberEntityData phone) {
  assert(phone != null);
  return json.encode(<String, String>{
    'number': phone.number,
    'label': phone.label,
  });
}

/// Decodes [String] into a structured [PhoneNumberEntityData].
PhoneNumberEntityData _decode(String data) {
  assert(data != null);
  assert(data.isNotEmpty);

  try {
    Map<String, String> decodedJson = json.decode(data);
    return new PhoneNumberEntityData(
      number: decodedJson['number'],
      label: decodedJson['label'] ?? '',
    );
  } on Exception catch (e) {
    // since this is just a first pass, not really going to do too much
    // additional validation here but would like to know if this ever does
    // error out
    log.warning('$_kType entity error when decoding from json string: $json'
        '\nerror: $e');
    rethrow;
  }
}
