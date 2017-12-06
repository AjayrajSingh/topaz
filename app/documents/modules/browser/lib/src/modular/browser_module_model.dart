// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:lib.agent.fidl.agent_controller/agent_controller.fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.fidl/service_provider.fidl.dart';
import 'package:lib.component.fidl/component_context.fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.module.fidl/module_context.fidl.dart';
import 'package:lib.module.fidl/module_controller.fidl.dart';
import 'package:lib.module_resolver.dart/daisy_builder.dart';
import 'package:lib.story.fidl/link.fidl.dart';
import 'package:lib.surface.fidl/surface.fidl.dart';
import 'package:lib.widgets/modular.dart';
import 'package:topaz.app.documents.services/document.fidl.dart' as doc_fidl;

const String _kInfoModuleUrl = 'file:///system/apps/documents/info';

/// The ModuleModel for the document browser
class BrowserModuleModel extends ModuleModel {
  // Interface Proxy. This is how we talk to the Doc FIDL
  final doc_fidl.DocumentInterfaceProxy _docsInterfaceProxy =
      new doc_fidl.DocumentInterfaceProxy();

  /// Used to talk to agents
  final AgentControllerProxy _agentControllerProxy = new AgentControllerProxy();

  /// Used to start and stop modules from within the Browser module
  final ModuleControllerProxy _moduleController = new ModuleControllerProxy();

  /// List of all documents for this Document Provider
  List<doc_fidl.Document> documents = <doc_fidl.Document>[];

  /// Currently selected Document
  doc_fidl.Document _currentDoc;

  /// True if we are in image preview mode
  bool _previewMode = false;

  /// True if loading docs.
  bool _loading = true;

  /// True if the Info Module is opened for a document
  bool _infoModuleOpen = false;

  /// Constructor
  BrowserModuleModel();

  /// True if loading docs.
  bool get loading => _loading;

  /// True if the Info Module is opened for a document
  bool get infoModuleOpen => _infoModuleOpen;

  /// Sets the document location to preview
  // TODO(maryxia) SO-967 - no need to do a get() to download to a
  // document location if the file is publicly accessible
  void setPreviewDocLocation() {
    _docsInterfaceProxy.get(_currentDoc.id, (doc_fidl.Document doc) {
      // Check that user has not navigated away to another doc
      if (_currentDoc.id == doc.id) {
        _currentDoc = doc;
        notifyListeners();
        log.fine('Downloaded file to local /tmp');
      }
    });
  }

  /// Implements the Document interface to List documents
  /// Saves the updated list of documents to the model
  // TODO(maryxia) SO-913 add error modes to doc_fidl
  void listDocs() {
    _loading = true;
    notifyListeners();
    _docsInterfaceProxy.list((List<doc_fidl.Document> docs) {
      documents = docs;
      _loading = false;
      notifyListeners();
      log.fine('Retrieved list of documents for BrowserModuleModel');
    });
  }

  /// Toggles the Info Module view for a [doc_fidl.Document]
  void toggleInfo() {
    if (_infoModuleOpen) {
      _moduleController.stop(() {
        _infoModuleOpen = false;
        notifyListeners();
      });
    } else {
      moduleContext.startModuleInShell(
        'info',
        _kInfoModuleUrl,
        null, // default link
        null,
        _moduleController.ctrl.request(),
        new SurfaceRelation(
          arrangement: SurfaceArrangement.copresent,
          dependency: SurfaceDependency.dependent,
          emphasis: 0.5,
        ),
        false,
      );
      _infoModuleOpen = true;
      notifyListeners();
    }
  }

  /// Creates an Entity Reference for the currently-selected doc
  /// The Resolver can use this Entity to figure out what relevant module to open
  void createDocEntityRef() {
    // Make Entity Ref for this doc
    _docsInterfaceProxy.createEntityReference(_currentDoc, (String entityRef) {
      log.fine('Retrieved an Entity Ref at $entityRef');
      // TODO(maryxia) SO-788 actually do something with the entity

      // Use DaisyBuilder to create a Daisy that stores an entityRef
      // for this Document
      // TODO(maryxia) SO-1014 pass in an entity for the Noun
      DaisyBuilder daisyBuilder = new DaisyBuilder.verb(
          'com.google.fuchsia.play')
        ..addNoun('asset',
            'http://ia800201.us.archive.org/12/items/BigBuckBunny_328/BigBuckBunny.ogv');
      log.fine('Created Daisy for $_currentDoc.id');

      // Open a new module using Module Resolution
      moduleContext.startDaisyInShell('video', daisyBuilder.daisy, null, null,
          _moduleController.ctrl.request(), null);
      log.fine('Opened a new module');
      notifyListeners();
    });
  }

  /// Updates the currently-selected doc
  /// Also sets the currentDocId in the Link
  set currentDoc(doc_fidl.Document doc) {
    _currentDoc = doc;
    link.set(const <String>['currentDocId'], JSON.encode(doc.id));
    notifyListeners();
  }

  /// Gets the currently-selected doc
  doc_fidl.Document get currentDoc => _currentDoc;

  /// Gets whether we should be showing the image preview mode
  bool get previewMode => _previewMode;

  /// Sets whether we should be showing the image preview mode
  set previewMode(bool show) {
    _previewMode = show;
    notifyListeners();
  }

  @override
  Future<Null> onReady(
    ModuleContext moduleContext,
    Link link,
  ) async {
    super.onReady(moduleContext, link);

    // The below is used to connect to the DocumentProvider service
    ComponentContextProxy componentContext = new ComponentContextProxy();
    moduleContext.getComponentContext(componentContext.ctrl.request());
    ServiceProviderProxy serviceProviderProxy = new ServiceProviderProxy();

    // The incomingServices here are the ones sent from outgoingServices in the
    // DocumentsAgent
    componentContext.connectToAgent(
      // TODO(maryxia) SO-880 get this from file manifest and add a check for
      // whether it can be found in the system
      // launches the application at this location, as if it were an agent
      'documents_content_provider',
      serviceProviderProxy.ctrl.request(),
      _agentControllerProxy.ctrl.request(),
    );
    // Connect the DocumentsInterfaceProxy to a service that the agent manages.
    // Otherwise, you've only connected to the Agent, and can't perform actions.
    connectToService(serviceProviderProxy, _docsInterfaceProxy.ctrl);
    serviceProviderProxy.ctrl.close();
    componentContext.ctrl.close();
    listDocs();
    notifyListeners();
    log.fine('BrowserModuleModel onReady complete');
  }

  @override
  void onStop() {
    _docsInterfaceProxy.ctrl.close();
    _agentControllerProxy.ctrl.close();
    _moduleController.ctrl.close();
  }
}
