// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// The [EntityCodec] is a typed [Codec] which translates
/// entity data between the [Uint8List] wire format and a
/// dart object.
///
/// [EntityCodec]s have a specific semantic type and encoding
/// which allow them to operate with the entity system.
abstract class EntityCodec<T> extends Codec<T, Uint8List> {
  /// The semantic type of the entity which this codec supports.
  /// This type will be used when requesting entities from the
  /// framework.
  final String type;

  /// The encoding that this [EntityCodec] knows how to encode/decode data
  final String encoding;

  /// The default constructor.
  EntityCodec({
    @required this.type,
    @required this.encoding,
  })  : assert(type != null),
        assert(encoding != null);
}
