// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../entity_codec.dart';
import 'documents_id_entity_data.dart';

export 'documents_id_entity_data.dart';

/// This [EntityCodec] translates Entity source data to and from the structured
/// [DocumentsIdEntityData].
class DocumentsIdEntityCodec extends EntityCodec<DocumentsIdEntityData> {
  /// Create an instance of [DocumentsIdEntityCodec].
  DocumentsIdEntityCodec()
      : super(
          type: 'com.fuchsia.documents.id',
          encode: _encode,
          decode: _decode,
        );
}

/// Encodes [DocumentsIdEntityData] into a [String].
String _encode(DocumentsIdEntityData data) {
  if (data == null) {
    return null;
  }
  return data.id;
}

/// Decodes [String] into a structured [DocumentsIdEntityData].
DocumentsIdEntityData _decode(String data) {
  return new DocumentsIdEntityData(id: data);
}
