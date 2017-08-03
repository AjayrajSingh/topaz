// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.logging/logging.dart';

/// A document class for holding the query string of the gallery module.
class GalleryQueryDocument {
  /// The document root.
  static const String docroot = 'image search';

  /// The query path to use when getting / updating Link data.
  static const List<String> path = const <String>[docroot];

  /// The query string key.
  static const String _kQueryKey = 'query';

  /// The query string value.
  String queryString;

  /// Creates an empty instance of [GalleryQueryDocument].
  GalleryQueryDocument();

  /// Creates a new instance of [GalleryQueryDocument] from the given json map.
  ///
  /// The provided json map must be the one under the [docroot].
  GalleryQueryDocument.fromJson(Map<String, dynamic> json) {
    try {
      queryString = json[_kQueryKey];
    } catch (e) {
      // This is not really an error case.
      log.fine('No image picker query key found in json.');
    }
  }

  /// Encodes this document into a json map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      _kQueryKey: queryString,
    };
  }
}
