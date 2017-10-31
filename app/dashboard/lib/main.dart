// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app.dart/app.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

import 'build_status_model.dart';
import 'dashboard_app.dart';
import 'dashboard_module_model.dart';

const String _kBaseURL = 'https://luci-scheduler.appspot.com/jobs/fuchsia/';
const List<List<List<String>>> _kTargetsMap = const <List<List<String>>>[
  const <List<String>>[
    const <String>[
      'fuchsia-aarch64-linux-debug',
      'aarch64-linux-debug',
      'fuchsia'
    ],
    const <String>[
      'fuchsia-aarch64-linux-release',
      'aarch64-linux-release',
      'fuchsia'
    ],
    const <String>[
      'fuchsia-x86_64-linux-debug',
      'x86_64-linux-debug',
      'fuchsia'
    ],
    const <String>[
      'fuchsia-x86_64-linux-release',
      'x86_64-linux-release',
      'fuchsia'
    ],
  ],
  const <List<String>>[
    const <String>['topaz-aarch64-linux-debug', 'aarch64-linux-debug', 'topaz'],
    const <String>[
      'topaz-aarch64-linux-release',
      'aarch64-linux-release',
      'topaz'
    ],
    const <String>['topaz-x86_64-linux-debug', 'x86_64-linux-debug', 'topaz'],
    const <String>[
      'topaz-x86_64-linux-release',
      'x86_64-linux-release',
      'topaz'
    ],
  ],
  const <List<String>>[
    const <String>[
      'peridot-aarch64-linux-debug',
      'aarch64-linux-debug',
      'peridot'
    ],
    const <String>[
      'peridot-aarch64-linux-release',
      'aarch64-linux-release',
      'peridot'
    ],
    const <String>[
      'peridot-x86_64-linux-debug',
      'x86_64-linux-debug',
      'peridot'
    ],
    const <String>[
      'peridot-x86_64-linux-release',
      'x86_64-linux-release',
      'peridot'
    ],
  ],
  const <List<String>>[
    const <String>[
      'garnet-aarch64-linux-debug',
      'aarch64-linux-debug',
      'garnet'
    ],
    const <String>[
      'garnet-aarch64-linux-release',
      'aarch64-linux-release',
      'garnet'
    ],
    const <String>['garnet-x86_64-linux-debug', 'x86_64-linux-debug', 'garnet'],
    const <String>[
      'garnet-x86_64-linux-release',
      'x86_64-linux-release',
      'garnet'
    ],
  ],
  const <List<String>>[
    const <String>[
      'zircon-pc-x86-64-clang',
      'zircon-pc-x86-64-clang',
      'zircon'
    ],
    const <String>['zircon-pc-x86-64-gcc', 'zircon-pc-x86-64-gcc', 'zircon'],
    const <String>[
      'zircon-qemu-arm64-clang',
      'zircon-qemu-arm64-clang',
      'zircon'
    ],
    const <String>['zircon-qemu-arm64-gcc', 'zircon-qemu-arm64-gcc', 'zircon'],
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

  final List<List<BuildStatusModel>> buildStatusModels =
      <List<BuildStatusModel>>[];

  for (List<List<String>> buildConfigs in _kTargetsMap) {
    List<BuildStatusModel> categoryModels = <BuildStatusModel>[];
    for (List<String> config in buildConfigs) {
      BuildStatusModel buildStatusModel = new BuildStatusModel(
        type: config[2],
        name: config[1],
        url: '$_kBaseURL${config[0]}',
      )..start();
      categoryModels.add(buildStatusModel);
    }
    buildStatusModels.add(categoryModels);
  }

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
            // ignore: avoid_function_literals_in_foreach_calls
            .forEach((BuildStatusModel model) => model.refresh());
      },
      onLaunchUrl: dashboardModuleModel.launchWebView,
    ),
  );

  runApp(moduleWidget);

  moduleWidget.advertise();
  dashboardModuleModel.loadDeviceMap();
}
