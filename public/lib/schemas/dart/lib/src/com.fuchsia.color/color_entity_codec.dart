// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../entity_codec.dart';
import '../parse_int.dart';
import 'color_entity_data.dart';

export 'color_entity_data.dart';

/// This [EntityCodec] translates Entity source data to and from the structured
/// [ColorEntityData].
class ColorEntityCodec extends EntityCodec<ColorEntityData> {
  /// Create an instance of [ColorEntityCodec].
  ColorEntityCodec()
      : super(
          type: 'com.fuchsia.color',
          encode: _encode,
          decode: _decode,
        );
}

/// Encodes [ColorEntityData] into a [String].
String _encode(ColorEntityData data) {
  assert(data != null);

  return data.value.toString();
}

/// Decodes [String] into a structured [ColorEntityData].
ColorEntityData _decode(String data) {
  assert(data != null);
  assert(data.isNotEmpty);

  final int value = parseInt(data);
  return new ColorEntityData(value: value);
}
