// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JSON;

import 'package:gallery/fixtures.dart';
import 'package:gallery/models.dart';
import 'package:test/test.dart';

void main() {
  GalleryFixtures fixtures = new GalleryFixtures();

  test('GallerySelectionDocument JSON encode / decode', () {
    GallerySelectionDocument doc = fixtures.gallerySelectionDocument();

    String encoded = JSON.encode(doc);
    Map<String, dynamic> json = JSON.decode(encoded);
    GallerySelectionDocument hydrated =
        new GallerySelectionDocument.fromJson(json);

    expect(hydrated.selectedImages, orderedEquals(doc.selectedImages));
  });
}
