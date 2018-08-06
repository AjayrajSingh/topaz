// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.schemas.dart/entity_codec.dart';

/// Codec for encoding/decoding a string across a link.
class ResultCodeEntityCodec extends EntityCodec<String> {
  ResultCodeEntityCodec()
      : super(
          type: 'com.fuchsia.string',
          encode: (String s) => s,
          decode: (String s) => s,
        );
}
