// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:fuchsia.fidl.documents/documents.dart' as doc_fidl;
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets.dart/model.dart';
import 'package:meta/meta.dart';

const String _kDefaultNavName = 'Documents';
const String _kDefaultRootDir = 'root';

/// A method which is called when a document needs to be resolved.
typedef void OnResolveDocument(String entityRef);

/// A method which is called when the current document is updated.
/// The document may be null if the current document is being deselected.
typedef void OnUpdateCurrentDocument(doc_fidl.Document doc);

/// A method which is called when is response to the [toggleInfo()] method.
typedef void OnToggleInfo(bool showInfo);

/// The model object for the Browser module
class BrowserModel extends Model {
  /// The document interface which is used to inflate documents
  final doc_fidl.DocumentInterface documentInterface;

  /// A method which is called in response to [resolveDocuement()] allowing
  /// for users of this class to determine how the document should be resolved.
  final OnResolveDocument onResolveDocument;

  /// A method which is called when the current document is updated.
  final OnUpdateCurrentDocument onUpdateCurrentDocument;

  /// A method which is called in response to [toggleInfo()].
  final OnToggleInfo onToggleInfo;

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

  /// The constructor for the [BrowserModel].
  BrowserModel({
    @required this.documentInterface,
    @required this.onResolveDocument,
    @required this.onUpdateCurrentDocument,
    @required this.onToggleInfo,
  })  : assert(documentInterface != null),
        assert(onResolveDocument != null),
        assert(onUpdateCurrentDocument != null),
        assert(onToggleInfo != null);

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
    documentInterface.get(_currentDoc.id, (doc_fidl.Document doc) {
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
    documentInterface.list(currentDirectoryId, (List<doc_fidl.Document> docs) {
      documents = docs;
      _navName = currentDirectoryName;
      _navId = currentDirectoryId;
      _loading = false;
      notifyListeners();
      log.fine('Retrieved list of documents for BrowserModel');
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
    _infoModuleOpen = !_infoModuleOpen;
    onToggleInfo(_infoModuleOpen);
    notifyListeners();
  }

  /// Resolves the [Document] by creating an entity ref and passing it to
  /// [onResolveDocument].
  void resolveDocument() {
    // Download the Document we want to resolve (currently, only video)
    // See SO-1084 for why we have to download the doc
    // Make Entity Ref for this doc
    documentInterface.createEntityReference(_currentDoc, (String entityRef) {
      log.fine('Retrieved an Entity Ref at $entityRef');
      onResolveDocument(entityRef);
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
    _currentDoc = _currentDoc == doc ? null : doc;
    onUpdateCurrentDocument(_currentDoc);
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
}
