// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

/// Holds strucutred data decoded from the document id's data.
class DocumentsIdEntityData {
  /// A string representing this documents id
  final String id;

  /// Create a new instance of [DocumentsIdEntityData].
  const DocumentsIdEntityData({
    @required this.id,
  }) : assert(id != null);
}
