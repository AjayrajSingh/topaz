// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_flux/flutter_flux.dart';

import 'src/module_data_module_model.dart';
import 'src/stores.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter/material.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

final ApplicationContext _appContext = new ApplicationContext.fromStartupInfo();

class ModuleDataScreen extends StoreWatcher {
  ModuleDataScreen({Key key}) : super(key: key);

  @override
  void initStores(ListenToStore listenToStore) {
    listenToStore(moduleDataStoreToken);
  }

  @override
  Widget build(BuildContext context, Map<StoreToken, Store> stores) {
    final ModuleDataStore moduleDataStore = stores[moduleDataStoreToken];
    return new DefaultTextStyle(
        style: Theme
            .of(context)
            .textTheme
            .subhead
            .copyWith(color: Colors.red[400]),
        child: new Padding(
            padding: const EdgeInsets.all(16.0),
            child: new Text(
                "Resolution Failed\n\nLink value: ${moduleDataStore.linkValue}")));
  }
}

void main() {
  setupLogger(name: 'maxwell/resolution_failed');

  ModuleDataModuleModel moduleModel = new ModuleDataModuleModel();
  ModuleWidget<ModuleDataModuleModel> moduleWidget =
      new ModuleWidget<ModuleDataModuleModel>(
    moduleModel: moduleModel,
    applicationContext: new ApplicationContext.fromStartupInfo(),
    child: new MaterialApp(
      title: 'Resolution Failed',
      theme: new ThemeData(
          primarySwatch: Colors.purple, accentColor: Colors.orangeAccent[400]),
      home: new ModuleDataScreen(),
    ),
  )..advertise();

  runApp(moduleWidget);
}
