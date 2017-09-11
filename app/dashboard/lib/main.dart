// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app.dart/app.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

import 'build_status_model.dart';
import 'dashboard_app.dart';
import 'dashboard_module_model.dart';

const String _kBaseURL = 'https://luci-scheduler.appspot.com/jobs/fuchsia/';
const List<List<List<String>>> _kTargetsMap = const <List<List<String>>>[
  const <List<String>>[
    const <String>[
      'fuchsia-x86_64-linux-debug',
      'x86_64-linux-debug',
      'fuchsia'
    ],
    const <String>[
      'fuchsia-aarch64-linux-debug',
      'aarch64-linux-debug',
      'fuchsia'
    ],
    const <String>[
      'fuchsia-x86_64-linux-release',
      'x86_64-linux-release',
      'fuchsia'
    ],
    const <String>[
      'fuchsia-aarch64-linux-release',
      'aarch64-linux-release',
      'fuchsia'
    ],
  ],
  const <List<String>>[
    const <String>[
      'drivers-x86_64-linux-debug',
      'x86_64-linux-debug',
      'drivers'
    ],
    const <String>[
      'drivers-aarch64-linux-debug',
      'aarch64-linux-debug',
      'drivers'
    ],
    const <String>[
      'drivers-x86_64-linux-release',
      'x86_64-linux-release',
      'drivers'
    ],
    const <String>[
      'drivers-aarch64-linux-release',
      'aarch64-linux-release',
      'drivers'
    ],
  ],
  const <List<String>>[
    const <String>[
      'magenta-qemu-arm64-gcc',
      'magenta-qemu-arm64-gcc',
      'magenta'
    ],
    const <String>[
      'magenta-pc-x86-64-gcc',
      'magenta-pc-x86-64-gcc',
      'magenta'
    ],
    const <String>[
      'magenta-qemu-arm64-clang',
      'magenta-qemu-arm64-clang',
      'magenta'
    ],
    const <String>[
      'magenta-pc-x86-64-clang',
      'magenta-pc-x86-64-clang',
      'magenta'
    ],
  ],
  const <List<String>>[
    const <String>['web_view-x86_64-linux', 'x86_64-linux', 'web_view'],
    const <String>['web_view-aarch64-linux', 'aarch64-linux', 'web_view'],
    const <String>['jiri-x86_64-linux', 'x86_64-linux', 'jiri'],
    const <String>['jiri-x86_64-mac', 'x86_64-mac', 'jiri'],
  ]
];

void main() {
  setupLogger();

  http.Client client = createHttpClient();
  final List<List<BuildStatusModel>> buildStatusModels =
      <List<BuildStatusModel>>[];

  _kTargetsMap.forEach((List<List<String>> buildConfigs) {
    List<BuildStatusModel> categoryModels = <BuildStatusModel>[];
    buildConfigs.forEach((List<String> config) {
      BuildStatusModel buildStatusModel = new BuildStatusModel(
        type: config[2],
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
