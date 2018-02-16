// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
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

const String _kInfoModuleUrl = 'documents_info';

const SurfaceRelation _kSurfaceRelation = const SurfaceRelation(
  arrangement: SurfaceArrangement.copresent,
  dependency: SurfaceDependency.dependent,
  emphasis: 0.5,
);

const String _kDefaultNavName = 'Documents';
const String _kDefaultRootDir = 'root';

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

  /// Currently selected Document in single-select mode
  doc_fidl.Document _currentDoc;

  /// List of docs toggled on in multi-select mode
  List<doc_fidl.Document> _selectedDocs = <doc_fidl.Document>[];

  /// True if we are in image preview mode
  bool _previewMode = false;

  /// True if loading docs.
  bool _loading = true;

  /// True if the Info Module is opened for a document
  bool _infoModuleOpen = false;

  /// True if we are in Grid View. False if we are in List View
  bool _gridView = true;

  // Name of where we are in the navigation path (i.e. what folder we're in)
  String _navName = _kDefaultNavName;

  // Id of the folder we're currently in, in the navigation path
  String _navId = _kDefaultRootDir;

  /// Constructor
  BrowserModuleModel();

  /// True if loading docs.
  bool get loading => _loading;

  /// True if the Documents are laid out in Grid View
  bool get gridView => _gridView;

  /// True if the Info Module is opened for a document
  bool get infoModuleOpen => _infoModuleOpen;

  /// Gets the name of the current folder we're in
  String get navName => _navName;

  /// Gets the ID of the current folder we're in
  String get navId => _navId;

  /// List of selected documents in multi-select mode
  List<doc_fidl.Document> get selectedDocs =>
      new UnmodifiableListView<doc_fidl.Document>(_selectedDocs);

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
  void listDocs(String currentDirectoryId, String currentDirectoryName) {
    _loading = true;
    notifyListeners();
    _docsInterfaceProxy.list(currentDirectoryId,
        (List<doc_fidl.Document> docs) {
      documents = docs;
      _navName = currentDirectoryName;
      _navId = currentDirectoryId;
      _loading = false;
      notifyListeners();
      log.fine('Retrieved list of documents for BrowserModuleModel');
    });
  }

  /// Whether a Document can be previewed by the image viewer
  bool canBePreviewed(doc_fidl.Document doc) {
    return doc != null && doc.mimeType.startsWith('image/');
  }

  /// Toggles between List and Grid view
  void toggleGridView() {
    _gridView = !_gridView;
    notifyListeners();
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
        _kSurfaceRelation,
        false,
      );
      _infoModuleOpen = true;
      notifyListeners();
    }
  }

  /// Resolves the [Document] into a new module.
  ///
  /// Creates an Entity Reference for the currently-selected doc.
  /// Create a Daisy, passing in the Entity Reference.
  /// The Resolver then figures out what relevant module to open.
  void resolveDocument() {
    // Download the Document we want to resolve (currently, only video)
    // See SO-1084 for why we have to download the doc
    // Make Entity Ref for this doc
    _docsInterfaceProxy.createEntityReference(_currentDoc, (String entityRef) {
      log.fine('Retrieved an Entity Ref at $entityRef');
      // Use DaisyBuilder to create a Daisy that stores an entityRef
      // for this Document
      DaisyBuilder daisyBuilder =
          new DaisyBuilder.verb('com.google.fuchsia.preview')
            ..addNoun('entityRef', entityRef);
      log.fine('Created Daisy for $_currentDoc.id');

      // Open a new module using Module Resolution
      moduleContext.startDaisyInShell(
        'video',
        daisyBuilder.daisy,
        null,
        null,
        _moduleController.ctrl.request(),
        _kSurfaceRelation,
        (StartDaisyStatus status) {
          // Handle daisy resolution here
          log.info('Start daisy status = $status');
        },
      );
      log.fine('Opened a new module');
      notifyListeners();
    });
  }

  /// Updates the currently-selected doc
  /// If the doc had not been selected, it now becomes selected
  /// If the user had already selected this doc, selecting it again will
  /// "unselect" it
  /// We are allowed to set the currently-selected doc to null. For example,
  /// when the list of documents initially loads, no doc has been selected.
  /// When a user selects, and then immediately unselects the same doc, the
  /// _currentDoc becomes null.
  ///
  /// Also updates the currentDocId in the Link accordingly
  void updateCurrentlySelectedDoc(doc_fidl.Document doc) {
    if (_currentDoc == doc) {
      _currentDoc = null;
      link.set(const <String>['currentDocId'], JSON.encode(null));
    } else {
      _currentDoc = doc;
      link.set(const <String>['currentDocId'], JSON.encode(doc.id));
    }
    notifyListeners();
  }

  /// Sets the entire list of _selectedDocs
  /// This is mostly used to clear the list of selected docs
  set selectedDocs(List<doc_fidl.Document> docs) {
    _selectedDocs = docs;
    notifyListeners();
  }

  /// Updates the selected docs (for multi-select)
  /// _currentDoc is purposely ignored for multi-select
  /// If the doc is not in the list, it is added
  /// If you had previously selected a doc, updating it will "unselect" it
  void updateSelectedDocs(doc_fidl.Document doc) {
    _currentDoc = null;
    if (_selectedDocs.contains(doc)) {
      _selectedDocs.remove(doc);
    } else {
      _selectedDocs.add(doc);
    }
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
    _docsInterfaceProxy.getContentProviderName((String name) {
      listDocs(_kDefaultRootDir, name);
    });
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
