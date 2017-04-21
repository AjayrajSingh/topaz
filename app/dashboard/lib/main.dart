// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:lib.widgets/modular.dart';

import 'build_status_model.dart';
import 'dashboard_app.dart';
import 'dashboard_module_model.dart';

const String _kBaseURL = 'https://luci-scheduler.appspot.com/jobs/fuchsia/';
const Map<String, List<List<String>>> _kTargetsMap =
    const <String, List<List<String>>>{
  'fuchsia': const <List<String>>[
    const <String>['fuchsia-x86_64-linux-debug', 'x86_64-linux-debug'],
    const <String>['fuchsia-aarch64-linux-debug', 'aarch64-linux-debug'],
    const <String>['fuchsia-x86_64-linux-release', 'x86_64-linux-release'],
    const <String>['fuchsia-aarch64-linux-release', 'aarch64-linux-release'],
  ],
  'fuchsia-drivers': const <List<String>>[
    const <String>['drivers-x86_64-linux-debug', 'x86_64-linux-debug'],
    const <String>['drivers-aarch64-linux-debug', 'aarch64-linux-debug'],
    const <String>['drivers-x86_64-linux-release', 'x86_64-linux-release'],
    const <String>['drivers-aarch64-linux-release', 'aarch64-linux-release'],
  ],
  'magenta': const <List<String>>[
    const <String>['magenta-aarch64-linux-gcc', 'aarch64-linux-gcc'],
    const <String>['magenta-x86_64-linux-gcc', 'x86_64-linux-gcc'],
    const <String>['magenta-aarch64-linux-clang', 'aarch64-linux-clang'],
    const <String>['magenta-x86_64-linux-clang', 'x86_64-linux-clang'],
  ],
  'jiri': const <List<String>>[
    const <String>['jiri-x86_64-linux', 'x86_64-linux'],
    const <String>['jiri-x86_64-mac', 'x86_64-mac'],
  ]
};

void main() {
  http.Client client = createHttpClient();
  final List<List<BuildStatusModel>> buildStatusModels =
      <List<BuildStatusModel>>[];

  _kTargetsMap.forEach((String categoryName, List<List<String>> buildConfigs) {
    List<BuildStatusModel> categoryModels = <BuildStatusModel>[];
    buildConfigs.forEach((List<String> config) {
      BuildStatusModel buildStatusModel = new BuildStatusModel(
        type: categoryName,
        name: config[1],
        url: _kBaseURL + config[0],
        client: client,
      );
      buildStatusModel.start();
      categoryModels.add(buildStatusModel);
    });
    buildStatusModels.add(categoryModels);
  });

  ApplicationContext applicationContext =
      new ApplicationContext.fromStartupInfo();

  DashboardModuleModel dashboardModuleModel = new DashboardModuleModel(
    applicationContext: applicationContext,
    buildStatusModels: buildStatusModels,
  );

  ModuleWidget<DashboardModuleModel> moduleWidget =
      new ModuleWidget<DashboardModuleModel>(
    applicationContext: applicationContext,
    moduleModel: dashboardModuleModel,
    child: new DashboardApp(
      buildStatusModels: buildStatusModels,
      onRefresh: () {
        buildStatusModels
            .expand((List<BuildStatusModel> models) => models)
            .forEach((BuildStatusModel model) => model.refresh());

        // TODO(apwilson): Remove this hack once we have a proper story shell to
        // remove the added web view.
        dashboardModuleModel.closeWebView();
      },
      onLaunchUrl: dashboardModuleModel.launchWebView,
    ),
  );

  runApp(moduleWidget);

  moduleWidget.advertise();
  dashboardModuleModel.loadDeviceMap();
}
