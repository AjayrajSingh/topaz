// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JSON;

import 'package:gallery/fixtures.dart';
import 'package:gallery/models.dart';
import 'package:test/test.dart';

void main() {
  GalleryFixtures fixtures = new GalleryFixtures();

  test('GalleryQueryDocument JSON encode / decode', () {
    GalleryQueryDocument doc = fixtures.galleryQueryDocument();

    String encoded = JSON.encode(doc);
    Map<String, dynamic> json = JSON.decode(encoded);
    GalleryQueryDocument hydrated = new GalleryQueryDocument.fromJson(json);

    expect(hydrated.queryString, equals(doc.queryString));
  });
}
