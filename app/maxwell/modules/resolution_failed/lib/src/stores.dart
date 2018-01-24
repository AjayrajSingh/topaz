// Copyright 2017, the Flutter project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter_flux/flutter_flux.dart';

// ignore_for_file: public_member_api_docs

class ModuleDataStore extends Store {
  ModuleDataStore() {
    // ignore: strong_mode_uses_dynamic_as_bottom
    triggerOnAction(setLinkValueAction, (String value) {
      _linkValue = value;
      return null;
    });
  }

  String _linkValue = '(not set)';

  String get linkValue => _linkValue;
}

final StoreToken moduleDataStoreToken = new StoreToken(new ModuleDataStore());

final Action<String> setLinkValueAction = new Action<String>();
