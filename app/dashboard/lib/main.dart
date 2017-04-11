// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/modular.dart';

import 'build_status_model.dart';
import 'dashboard_app.dart';
import 'dashboard_module_model.dart';

const String _kBaseURL = 'https://luci-scheduler.appspot.com/jobs/';
const Map<String, List<List<String>>> _kTargetsMap =
    const <String, List<List<String>>>{
  'fuchsia': const <List<String>>[
    const <String>['fuchsia/linux-x86-64-debug', 'linux-x86-64-debug'],
    const <String>['fuchsia/linux-arm64-debug', 'linux-arm64-debug'],
    const <String>['fuchsia/linux-x86-64-release', 'linux-x86-64-release'],
    const <String>['fuchsia/linux-arm64-release', 'linux-arm64-release'],
  ],
  'fuchsia-drivers': const <List<String>>[
    const <String>['fuchsia/drivers-linux-x86-64-debug', 'linux-x86-64-debug'],
    const <String>['fuchsia/drivers-linux-arm64-debug', 'linux-arm64-debug'],
    const <String>[
      'fuchsia/drivers-linux-x86-64-release',
      'linux-x86-64-release'
    ],
    const <String>[
      'fuchsia/drivers-linux-arm64-release',
      'linux-arm64-release'
    ],
  ],
  'magenta': const <List<String>>[
    const <String>['magenta/arm64-linux-gcc', 'arm64-linux-gcc'],
    const <String>['magenta/x86-64-linux-gcc', 'x86-64-linux-gcc'],
    const <String>['magenta/arm64-linux-clang', 'arm64-linux-clang'],
    const <String>['magenta/x86-64-linux-clang', 'x86-64-linux-clang'],
  ],
  'jiri': const <List<String>>[
    const <String>['jiri/linux-x86-64', 'linux-x86-64'],
    const <String>['jiri/mac-x86-64', 'mac-x86-64'],
  ]
};

void main() {
  final List<List<BuildStatusModel>> buildStatusModels =
      <List<BuildStatusModel>>[];

  _kTargetsMap.forEach((String categoryName, List<List<String>> buildConfigs) {
    List<BuildStatusModel> categoryModels = <BuildStatusModel>[];
    buildConfigs.forEach((List<String> config) {
      BuildStatusModel buildStatusModel = new BuildStatusModel(
        type: categoryName,
        name: config[1],
        url: _kBaseURL + config[0],
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
