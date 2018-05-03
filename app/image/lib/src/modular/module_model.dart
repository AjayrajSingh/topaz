// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show json;

import 'package:lib.app.dart/logging.dart';
import 'package:lib.widgets/modular.dart';

/// The model for the color module.
class ImageModuleModel extends ModuleModel {
  /// Gets the image uri.
  Uri get imageUri => _imageUri;
  Uri _imageUri;

  // TODO(vardhan): Deprecate 'image_url' in favour proper typing (eg.,
  // http://schema.org/image).
  @override
  void onNotify(String encoded) {
    log.fine('JSON: $encoded');
    // Expects Link to look something like this:
    // { "image_url" : "http:///www.example.com/image.gif" } or
    // { "image_url" : "/system/data/modules/image.gif" } or
    // { "asset": "http:///www.example.com/image.gif" } or
    // { "asset": { "contentUrl": "http:///www.example.com/image.gif" } }
    final dynamic doc = json.decode(encoded);
    if (doc is Map) {
      if (doc['image_url'] is String) {
        _imageUri = Uri.parse(doc['image_url']);
        notifyListeners();
      } else if (doc['asset'] is String) {
        // schema.org/image: URL to a image
        _imageUri = Uri.parse(doc['asset']);
        notifyListeners();
      } else if (doc['asset'] is Map && doc['contentUrl'] is String) {
        // schema.org/image: ImageObject
        _imageUri = Uri.parse(doc['asset']['contentUrl']);
        notifyListeners();
      }
    }
  }
}
