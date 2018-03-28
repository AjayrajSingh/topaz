// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:lib.logging/logging.dart';

import '../entity_codec.dart';
import 'email_entity_data.dart';

const String _kType = 'com.fuchsia.contact.email';

/// The [EntityCodec] that translates the [EmailEntityData].
class EmailEntityCodec extends EntityCodec<EmailEntityData> {
  /// Constructor
  EmailEntityCodec()
      : super(
          type: _kType,
          encode: _encode,
          decode: _decode,
        );
}

/// Encodes [EmailEntityData] into a [String].
String _encode(EmailEntityData email) {
  assert(email != null);

  return json.encode(<String, String>{
    'label': email.label,
    'value': email.value,
  });
}

/// Decodes [String] into a structured [EmailEntityData].
EmailEntityData _decode(String data) {
  assert(data != null);
  assert(data.isNotEmpty);
  try {
    Map<String, String> decodedJson = json.decode(data);
    return new EmailEntityData(
      value: decodedJson['value'],
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
