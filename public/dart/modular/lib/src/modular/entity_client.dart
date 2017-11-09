// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:lib.entity.fidl/entity.fidl.dart';
import 'package:json_schema/json_schema.dart' as json_schema;

/// Provides an idiomatic way to access and type-validate data from an [Entity].
class EntityClient {
  /// Constructor.
  EntityClient.fromEntity(this._entity);

  /// List of types this entity supports.
  Future<List<String>> getTypes() {
    Completer<List<String>> result = new Completer<List<String>>();
    _entity.getTypes(result.complete);
    return result.future;
  }

  /// Given one of the types returned from [getTypes], this method gets the data
  /// for it, validates it using [jsonTypeSchema], and returns non-null data if
  /// the data is valid.
  Future<String> getValidatedData(String type, String jsonTypeSchema) async {
    String data = await getData(type);
    json_schema.Schema schema =
        await json_schema.Schema.createSchema(JSON.decode(jsonTypeSchema));
    if (data != null && schema.validate(jsonTypeSchema)) {
      return data;
    }
    return null;
  }

  /// Returns the data associated with the given type without validating it.
  Future<String> getData(String type) {
    Completer<String> result = new Completer<String>();
    _entity.getData(type, result.complete);
    return result.future;
  }

  final EntityProxy _entity;
}
