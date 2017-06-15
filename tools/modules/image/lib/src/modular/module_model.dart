// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JSON;

import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

/// The model for the color module.
class ImageModuleModel extends ModuleModel {
  /// Gets the image uri.
  Uri get imageUri => _imageUri;
  Uri _imageUri;

  @override
  void onNotify(String json) {
    log.fine('JSON: $json');
    // Expects Link to look something like this:
    // { "image_url" : "http:///www.example.com/image.gif" } or
    // { "image_url" : "/system/data/modules/image.gif" }
    final dynamic doc = JSON.decode(json);
    if (doc is Map && doc['image_url'] is String) {
      _imageUri = Uri.parse(doc['image_url']);
      notifyListeners();
    }
  }
}
