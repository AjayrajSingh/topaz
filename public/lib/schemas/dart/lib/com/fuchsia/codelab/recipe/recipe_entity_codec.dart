// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.schemas.dart/entity_codec.dart';

const String _kRecipeEntityUri = 'com.fuchsia.codelab.recipe';

/// Convert a Recipe values to a form passable over a Link between
/// modules.
class RecipeEntityCodec extends StringListEntityCodec {
  /// Constuctor assigns the Entity type.
  RecipeEntityCodec() : super(_kRecipeEntityUri);
}
