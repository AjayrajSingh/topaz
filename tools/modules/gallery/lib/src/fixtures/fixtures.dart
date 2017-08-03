// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fixtures/fixtures.dart';

import '../models/query_document.dart';
import '../models/selection_document.dart';

/// Test fixtures class for gallery module.
class GalleryFixtures extends Fixtures {
  /// Returns a [GalleryQueryDocument] with a sample query string in it.
  GalleryQueryDocument galleryQueryDocument() =>
      new GalleryQueryDocument()..queryString = 'Sample Query';

  /// Returns a [GallerySelectionDocument] with some sample image urls in it.
  GallerySelectionDocument gallerySelectionDocument() =>
      new GallerySelectionDocument(
        initialSelection: <String>[
          'https://raw.githubusercontent.com/dvdwasibi/DogsOfFuchsia/master/coco.jpg',
          'https://raw.githubusercontent.com/dvdwasibi/DogsOfFuchsia/master/yoyo.jpg',
        ],
      );
}
