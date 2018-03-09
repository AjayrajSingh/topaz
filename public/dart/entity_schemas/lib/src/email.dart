// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:lib.logging/logging.dart';
import 'package:meta/meta.dart';

const String _kType = 'EmailAddress';

/// The Entity Schema for an email address
///
/// WIP for the first pass of work with Entities
class EmailAddress {
  /// Email address, e.g. littlePuppyCoco@cute.org
  final String value;

  /// Optional label to give for the email, e.g. Work, Personal...
  final String label;

  /// Constructor
  EmailAddress({
    @required this.value,
    this.label,
  })
      : assert(value != null && value.isNotEmpty);

  /// Instantiate an email address from a json string
  factory EmailAddress.fromJson(String encodedJson) {
    try {
      Map<String, String> decodedJson = json.decode(encodedJson);
      return new EmailAddress(
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

  /// Get the type of this entity
  static String getType() => _kType;

  @override
  String toString() => toJson();

  /// Helper function to encode an email address entity into a json string
  String toJson() {
    return json.encode(<String, String>{
      'label': label,
      'value': value,
    });
  }
}
