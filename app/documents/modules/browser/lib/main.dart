// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:fidl_documents/fidl.dart' as doc_fidl;
import 'package:fidl_modular/fidl.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.module_resolver.dart/intent_builder.dart';
import 'package:lib.schemas.dart/com.fuchsia.documents.dart';
import 'package:lib.widgets.dart/model.dart';

import 'src/models/browser_model.dart';
import 'src/widgets/browser.dart';

ModuleDriver _driver;
ModuleControllerClient _videoModuleControllerClient;
ModuleControllerClient _infoModuleControllerClient;

const SurfaceRelation _kSurfaceRelation = const SurfaceRelation(
  arrangement: SurfaceArrangement.copresent,
  dependency: SurfaceDependency.dependent,
  emphasis: 0.5,
);

final DocumentsIdEntityCodec _kDocumentsIdsCodec = new DocumentsIdEntityCodec();

void main() {
  setupLogger(name: 'documents-browser');

  final doc_fidl.DocumentInterfaceProxy docsInterfaceProxy =
      new doc_fidl.DocumentInterfaceProxy();

  _driver = new ModuleDriver(
    onTerminate: () {
      docsInterfaceProxy.ctrl.close();
      _videoModuleControllerClient?.terminate();
      _infoModuleControllerClient?.terminate();
    },
  );

  _driver
      .connectToAgentServiceWithProxy(
    'documents_content_provider',
    docsInterfaceProxy,
  )
      .then(
    (_) {
      log.info('Connected to agent');
    },
    onError: _handleError,
  );

  BrowserModel model = new BrowserModel(
    documentInterface: docsInterfaceProxy,
    onResolveDocument: _resolveDocument,
    onUpdateCurrentDocument: _updateCurrentDocument,
    onToggleInfo: _handleToggleInfo,
  );

  _driver.start().then(
        _handleStart,
        onError: _handleError,
      );

  runApp(
    new MaterialApp(
      home: new Material(
        child: new Directionality(
          textDirection: TextDirection.ltr,
          child: new ScopedModel<BrowserModel>(
            model: model,
            child: const Browser(),
          ),
        ),
      ),
    ),
  );
}

void _handleToggleInfo(bool show) {
  if (show) {
    IntentBuilder intentBuilder = new IntentBuilder.handler('documents_info')
      ..addParameterFromLink('id', 'id');

    _driver
        .startModule(
      module: 'documents_info',
      intent: intentBuilder.intent,
    )
        .then(
      (ModuleControllerClient client) {
        _infoModuleControllerClient = client;
        log.info('starting info module');
      },
      onError: _handleError,
    );
  } else {
    _infoModuleControllerClient?.terminate();
    _infoModuleControllerClient = null;
  }
}

void _resolveDocument(String entityRef) {
  IntentBuilder intentBuilder =
      new IntentBuilder.action('com.google.fuchsia.preview')
        ..addParameterFromEntityReference('entity', entityRef);

  _driver
      .startModule(
    module: 'video',
    intent: intentBuilder.intent,
    surfaceRelation: _kSurfaceRelation,
  )
      .then((ModuleControllerClient client) {
    _videoModuleControllerClient = client;
  });
}

void _updateCurrentDocument(doc_fidl.Document doc) {
  _driver
      .put('id', new DocumentsIdEntityData(id: doc.id), _kDocumentsIdsCodec)
      .then((_) {
    log.info('updated entity with document id: ${doc.id}');
  });
}

void _handleError(Error error, StackTrace stackTrace) {
  log.severe('An error ocurred', error, stackTrace);
}

void _handleStart(ModuleDriver module) {
  log.info('browser module ready');
}
