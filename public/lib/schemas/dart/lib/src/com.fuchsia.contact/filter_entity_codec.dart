// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:lib.app.dart/logging.dart';
import 'package:lib.schemas.dart/entity_codec.dart';

import 'filter_entity_data.dart';

/// The [EntityCodec] that translates [FilterEntityData]
class FilterEntityCodec extends EntityCodec<FilterEntityData> {
  /// Creates an instance of the codec
  FilterEntityCodec()
      : super(
          type: 'com.fuchsia.contact.filter',
          encode: _encode,
          decode: _decode,
        );
}

String _encode(FilterEntityData entity) {
  if (entity == null) {
    return null;
  }

  return json.encode(<String, String>{
    'prefix': entity.prefix,
    'detailType': entity.detailType.toString()
  });
}

FilterEntityData _decode(String data) {
  if (data == null || data.isEmpty) {
    return null;
  }

  FilterEntityData filter = new FilterEntityData();
  try {
    Map<String, String> decoded = json.decode(data).cast<String, String>();
    filter.prefix = decoded['prefix'];
    DetailType detailType;
    switch (data) {
      case 'email':
        detailType = DetailType.email;
        break;

      case 'phoneNumber':
        detailType = DetailType.phoneNumber;
        break;

      default:
        detailType = DetailType.custom;
        break;
    }
    filter.detailType = detailType;
  } on Exception catch (err, stackTrace) {
    log.warning('Error parsing FilterEntityData: $err\n$stackTrace');
  }

  return filter;
}
