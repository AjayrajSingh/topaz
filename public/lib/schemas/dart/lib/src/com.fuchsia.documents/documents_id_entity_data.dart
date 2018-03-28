// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Holds strucutred data decoded from the document id's data.
class DocumentsIdEntityData {
  /// A string representing this documents id or null if no document
  final String id;

  /// Create a new instance of [DocumentsIdEntityData].
  const DocumentsIdEntityData({
    this.id,
  });
}
