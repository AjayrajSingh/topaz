// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:lib.app.dart/logging.dart';
import 'package:meta/meta.dart';

const String _kType = 'PhoneNumber';

/// The Entity schema for a phone number
///
/// WIP for the first pass of work with Entities
class PhoneNumber {
  /// Phone number, e.g. 911, 1-408-111-2222
  final String number;

  /// Optional label to give for the phone entry, e.g. Cell, Home, Work...
  final String label;

  /// Constructor
  PhoneNumber({
    @required this.number,
    this.label,
  })
      : assert(number != null && number.isNotEmpty);

  /// Instantiate a phone number from a json string
  factory PhoneNumber.fromJson(String encodedJson) {
    try {
      Map<String, String> decodedJson = json.decode(encodedJson);
      return new PhoneNumber(
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

  /// Get the type of this entity
  static String getType() => _kType;

  @override
  String toString() => toJson();

  /// Helper function to encode a phone number entity into a json string
  String toJson() {
    return json.encode(<String, String>{
      'number': number,
      'label': label,
    });
  }
}
