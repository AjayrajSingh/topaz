// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:lib.app.fidl/service_provider.fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.module.fidl/module_context.fidl.dart';
import 'package:lib.story.fidl/link.fidl.dart';
import 'package:lib.widgets/modular.dart';

import 'stores.dart';

class ModuleDataModuleModel extends ModuleModel {
  /// Creates an instance of a [ModuleDataModuleModel]
  ModuleDataModuleModel();

  @override
  Future<Null> onReady(
    ModuleContext moduleContext,
    Link link,
    ServiceProvider incomingServices,
  ) async {
    super.onReady(moduleContext, link, incomingServices);
    log.fine('ModuleModel::onReady call');

    // Obtain the component context
    ComponentContextProxy componentContext = new ComponentContextProxy();
    moduleContext.getComponentContext(componentContext.ctrl.request());
    // ... do something with componentContext ...
    componentContext.ctrl.close();
  }

  @override
  void onNotify(String json) {
    log.fine('LinkWatcherImpl.notify() $json');
    dynamic doc = JSON.decode(json);
    JsonEncoder encoder = const JsonEncoder.withIndent('  ');
    String prettyprint = encoder.convert(doc);
    setLinkValueAction(prettyprint);
  }
}
