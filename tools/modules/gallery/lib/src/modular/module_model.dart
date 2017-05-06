// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show JSON;

import 'package:application.services/service_provider.fidl.dart';
import 'package:apps.modular.services.module/module_context.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:config/config.dart';
import 'package:lib.widgets/modular.dart';

const String _kContract = 'image search';
const String _kQueryKey = 'query';

void _log(String msg) {
  print('[gallery_module_model] $msg');
}

/// A [ModuleModel] providing the api id / key values for the gallery module.
class GalleryModuleModel extends ModuleModel {
  /// Gets the custom search id.
  String get customSearchId => _customSearchId;
  String _customSearchId;

  /// Gets the api key.
  String get apiKey => _apiKey;
  String _apiKey;

  /// Gets the query string provided via [Link].
  String get queryString => _queryString;
  String _queryString;

  @override
  Future<Null> onReady(
    ModuleContext moduleContext,
    Link link,
    ServiceProvider incomingServices,
  ) async {
    super.onReady(moduleContext, link, incomingServices);

    Config config = await Config.read('/system/data/modules/config.json');
    try {
      config.validate(<String>['google_search_key', 'google_search_id']);
      _customSearchId = config.get('google_search_id');
      _apiKey = config.get('google_search_key');
      notifyListeners();
    } catch (e) {
      _log('$e');
    }
  }

  @override
  void onNotify(String json) {
    dynamic decoded = JSON.decode(json);
    try {
      _queryString = decoded[_kContract][_kQueryKey];
    } catch (e) {
      _log('No image picker query key found in json.');
    }
    notifyListeners();
  }
}
