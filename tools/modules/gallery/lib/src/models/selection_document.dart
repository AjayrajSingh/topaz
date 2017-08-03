// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

/// A document class for holding the selected image urls of the gallery module.
class GallerySelectionDocument {
  /// The document root.
  static const String docroot = 'image selection';

  /// The query path to use when getting / updating Link data.
  static const List<String> path = const <String>[docroot];

  /// The selected images key.
  static const String _kSelectedImagesKey = 'selected images';

  /// The selected images.
  final List<String> _selectedImages;

  /// Creates an empty instance of [GallerySelectionDocument].
  GallerySelectionDocument({List<String> initialSelection})
      : _selectedImages = initialSelection != null
            ? new List<String>.from(initialSelection)
            : <String>[];

  /// Creates a new instance of [GallerySelectionDocument] from the given json
  /// map.
  ///
  /// The provided json map must be the one under the [docroot].
  factory GallerySelectionDocument.fromJson(Map<String, dynamic> json) {
    List<String> initialSelection;
    if (json is Map && json[_kSelectedImagesKey] is List<String>) {
      initialSelection = json[_kSelectedImagesKey];
    }
    return new GallerySelectionDocument(initialSelection: initialSelection);
  }

  /// Gets and Sets the selected images.
  List<String> get selectedImages =>
      new UnmodifiableListView<String>(_selectedImages);

  set selectedImages(List<String> selectedImages) {
    _selectedImages
      ..clear()
      ..addAll(selectedImages);
  }

  /// Encodes this document into a json map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      _kSelectedImagesKey: selectedImages,
    };
  }
}
