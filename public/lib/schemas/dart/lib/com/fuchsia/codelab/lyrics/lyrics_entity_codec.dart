// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show json;

import 'package:lib.logging/logging.dart';
import 'package:lib.schemas.dart/entity_codec.dart';

const String _kLyricsEntityUri = 'com.fuchsia.codelab.lyrics';

/// Convert list of stock ticker values to a form passable over a Link between
/// modules.
class LyricsEntityCodec extends StringListEntityCodec {
  /// Constuctor assigns the Entity type.
  LyricsEntityCodec() : super(_kLyricsEntityUri);
}
