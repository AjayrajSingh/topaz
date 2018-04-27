// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'document/document.dart';
import 'schema/schema.dart';

/// TODO: remove.
void placeholder() {}

/// The interface to the Sledge library.
class Sledge {
  /// Returns a new document that can be stored in Sledge.
  dynamic newDocument(Schema schema) {
    return new Document(this, schema);
  }
}
