// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:lib.logging/logging.dart';
import 'package:fuchsia.fidl.modular/modular.dart';
import 'package:lib.widgets/modular.dart';

import 'stores.dart';

// ignore_for_file: public_member_api_docs

class ModuleDataModuleModel extends ModuleModel {
  /// Creates an instance of a [ModuleDataModuleModel]
  ModuleDataModuleModel();

  @override
  Future<Null> onReady(
    ModuleContext moduleContext,
    Link link,
  ) async {
    super.onReady(moduleContext, link);
    log.fine('ModuleModel::onReady call');

    // Obtain the component context
    ComponentContextProxy componentContext = new ComponentContextProxy();
    moduleContext.getComponentContext(componentContext.ctrl.request());
    // ... do something with componentContext ...
    componentContext.ctrl.close();

    // Signal module watchers this module is ready to be rendered.
    moduleContext.ready();
  }

  @override
  void onNotify(String encoded) {
    log.fine('LinkWatcherImpl.notify() $json');
    dynamic doc = json.decode(encoded);
    JsonEncoder encoder = const JsonEncoder.withIndent('  ');
    String prettyprint = encoder.convert(doc);
    setLinkValueAction(prettyprint);
  }
}
