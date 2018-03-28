// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.schemas.dart/entity_codec.dart';

import 'detail_type_entity_data.dart';

/// The [EntityCodec] that translates [DetailTypeEntityData]
class DetailTypeEntityCodec extends EntityCodec<DetailTypeEntityData> {
  /// Creates an instance of the codec
  DetailTypeEntityCodec()
      : super(
          type: 'com.fuchsia.string',
          encode: _encode,
          decode: _decode,
        );
}

String _encode(DetailTypeEntityData entity) {
  assert(entity != null);
  return entity.toString();
}

DetailTypeEntityData _decode(String data) {
  assert(data != null);
  assert(data.isNotEmpty);

  DetailTypeEntityData detailType;

  switch (data) {
    case 'email':
      detailType = DetailTypeEntityData.email;
      break;

    case 'phoneNumber':
      detailType = DetailTypeEntityData.phoneNumber;
      break;

    default:
      detailType = DetailTypeEntityData.custom;
      break;
  }

  return detailType;
}
