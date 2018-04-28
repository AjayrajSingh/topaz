// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../entity_codec.dart';
import 'status_entity_data.dart';

export 'status_entity_data.dart';

/// This [EntityCodec] translates Entity source data to and from the structured
/// [StatusEntityData].
class StatusEntityCodec extends EntityCodec<StatusEntityData> {
  /// Create an instance of [StatusEntityCodec].
  StatusEntityCodec()
      : super(
          type: 'com.fuchsia.status',
          encode: _encode,
          decode: _decode,
        );
}

/// Encodes [StatusEntityData] into a [String].
String _encode(StatusEntityData data) {
  assert(data != null);

  return data.value;
}

/// Decodes [String] into a structured [StatusEntityData].
StatusEntityData _decode(String data) {
  assert(data != null);
  assert(data.isNotEmpty);

  return new StatusEntityData(value: data);
}
