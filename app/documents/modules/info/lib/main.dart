// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.schemas.dart/com.fuchsia.documents.dart';
import 'package:lib.widgets.dart/model.dart';
import 'package:fuchsia.fidl.documents/documents.dart' as doc_fidl;

import 'src/widgets/info.dart';

final DocumentsIdEntityCodec _kDocumentsIdsCodec = new DocumentsIdEntityCodec();

typedef void _DocumentResolver(DocumentsIdEntityData data);

void main() {
  setupLogger(name: 'documents_info');

  final doc_fidl.DocumentInterfaceProxy docsInterfaceProxy =
      new doc_fidl.DocumentInterfaceProxy();

  ValueModel<doc_fidl.Document> model = new ValueModel<doc_fidl.Document>();

  ModuleDriver driver = new ModuleDriver(
    onTerminateFromCaller: docsInterfaceProxy.ctrl.close,
  );

  // Connect to the service proxy
  driver
      .connectToAgentServiceWithProxy(
          'documents', docsInterfaceProxy)
      .then((_) {
    log.info('Connected to DocumentInterfaceProxy');
  }, onError: _handleError);

  // Listen to changes to the current document
  driver
      .watch('id', _kDocumentsIdsCodec)
      .listen(_makeDocumentResolver(docsInterfaceProxy, model));

  // Start the module
  driver.start().then(_handleStart, onError: _handleError);

  runApp(
    new MaterialApp(
      home: new Material(
        child: new Directionality(
          textDirection: TextDirection.ltr,
          child: new ScopedModel<ValueModel<doc_fidl.Document>>(
            model: model,
            child: new Info(),
          ),
        ),
      ),
    ),
  );
}

_DocumentResolver _makeDocumentResolver(doc_fidl.DocumentInterfaceProxy proxy,
    ValueModel<doc_fidl.Document> model) {
  void resolver(DocumentsIdEntityData data) {
    proxy.getMetadata(data.id, (doc_fidl.Document doc) {
      model.value = doc;
    });
  }

  return resolver;
}

void _handleError(Error error, StackTrace stackTrace) {
  log.severe('An error ocurred', error, stackTrace);
}

void _handleStart(ModuleDriver module) {
  log.info('document info module ready');
}
