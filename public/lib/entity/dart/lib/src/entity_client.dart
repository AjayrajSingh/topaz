// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_mem/fidl.dart' as fuchsia_mem;
import 'package:fidl_fuchsia_modular/fidl.dart' as fidl;
import 'package:json_schema/json_schema.dart' as json_schema;
import 'package:lib.app.dart/logging.dart';
import 'package:zircon/zircon.dart';

/// Provides an idiomatic way to access and type-validate data from an [fidl.Entity].
class EntityClient {
  /// The underlying [Proxy] used to send client requests to the
  /// [fidl.Entity] service.
  final fidl.EntityProxy proxy;

  /// Constructor.
  EntityClient() : proxy = new fidl.EntityProxy() {
    proxy.ctrl
      ..onBind = _handleBind
      ..onClose = _handleClose
      ..onConnectionError = _handleConnectionError
      ..onUnbind = _handleUnbind;
  }

  /// Constructor.
  EntityClient.fromEntity(this.proxy);

  /// List of types this entity supports.
  Future<List<String>> getTypes() {
    Completer<List<String>> result = new Completer<List<String>>();
    proxy.getTypes(result.complete);
    return result.future;
  }

  /// Given one of the types returned from [getTypes], this method gets the data
  /// for it, validates it using [jsonTypeSchema], and returns non-null data if
  /// the data is valid.
  Future<String> getValidatedData(String type, String jsonTypeSchema) async {
    String data = await getData(type);
    json_schema.Schema schema =
        await json_schema.Schema.createSchema(json.decode(jsonTypeSchema));
    if (data != null && schema.validate(jsonTypeSchema)) {
      return data;
    }
    return null;
  }

  Future<fuchsia_mem.Buffer> _getVmoData(String type) {
    Completer<fuchsia_mem.Buffer> result = new Completer<fuchsia_mem.Buffer>();
    proxy.getData(type, result.complete);
    return result.future;
  }

  /// Returns the data associated with the given type without validating it.
  Future<String> getData(String type) async {
    var buffer = await _getVmoData(type);
    var dataVmo = new SizedVmo(buffer.vmo.handle, buffer.size);
    var data = dataVmo.read(buffer.size);
    dataVmo.close();
    return utf8.decode(data.bytesAsUint8List());
  }

  /// Closes the underlying proxy connection, should be called as a response to
  /// Lifecycle::terminate (see https://goo.gl/MmZ2dc).
  Future<Null> terminate() async {
    log.info('terminate called');
    proxy.ctrl.close();
    return;
  }

  void _handleBind() {
    log.fine('proxy ready');
  }

  void _handleUnbind() {
    log.fine('proxy unbound');
  }

  void _handleClose() {
    log.fine('proxy closed');
  }

  void _handleConnectionError() {
    Exception err = new Exception('binding connection failed');
    throw err;
  }
}
