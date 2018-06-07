// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../schema/schema.dart';
import '../sledge.dart';
import 'document_id.dart';
import 'value_node.dart';

// TODO: Use the |_sledge| field.
// ignore_for_file: unused_field

/// Represents structured data that can be stored in Sledge.
class Document {
  Sledge _sledge;
  Schema _schema;
  ValueNode _value;
  DocumentId _documentId;

  /// Default constructor.
  Document(this._sledge, this._documentId) {
    _schema = _documentId.schema;
    _value = _schema.newValue();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return _value.noSuchMethod(invocation);
  }
}
