// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.schemas.dart/entity_codec.dart';

const String _kJsonEntityUri = 'com.fuchsia.json';

/// Converts a request to set the json into a form passable over a Link between
/// modules. This is functionally just a pass-through for the string, which
/// will be interpreted after decoding on the module-side.
class JsonEntityCodec extends EntityCodec<String> {
  /// Constuctor assigns the proper values to en/decode a the request.
  JsonEntityCodec()
      : super(
          type: _kJsonEntityUri,
          encode: (x) => x,
          decode: (x) => x,
        );
}
