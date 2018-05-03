// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dashboard/build_status_model.dart';
import 'package:dashboard/dashboard_app.dart';
import 'package:dashboard/dashboard_module_model.dart';
import 'package:dashboard/service/build_service.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.widgets/modular.dart';

const List<List<List<String>>> _kTargetsMap = const <List<List<String>>>[
  const <List<String>>[
    const <String>[
      'topaz-arm64-debug-qemu_kvm',
      'arm64-debug',
      'topaz',
    ],
    const <String>[
      'topaz-arm64-release-qemu_kvm',
      'arm64-release',
      'topaz',
    ],
    const <String>[
      'topaz-x64-debug-qemu_kvm',
      'x64-debug',
      'topaz',
    ],
    const <String>[
      'topaz-x64-release-qemu_kvm',
      'x64-release',
      'topaz',
    ],
  ],
  const <List<String>>[
    const <String>[
      'peridot-arm64-debug-qemu_kvm',
      'arm64-debug',
      'peridot',
    ],
    const <String>[
      'peridot-arm64-release-qemu_kvm',
      'arm64-releas',
      'peridot',
    ],
    const <String>[
      'peridot-x64-debug-qemu_kvm',
      'x64-debug',
      'peridot',
    ],
    const <String>[
      'peridot-x64-release-qemu_kvm',
      'x64-release',
      'peridot',
    ],
  ],
  const <List<String>>[
    const <String>[
      'garnet-arm64-debug-qemu_kvm',
      'arm64-debug',
      'garnet',
    ],
    const <String>[
      'garnet-arm64-release-qemu_kvm',
      'arm64-release',
      'garnet',
    ],
    const <String>[
      'garnet-x64-debug-qemu_kvm',
      'x64-debug',
      'garnet',
    ],
    const <String>[
      'garnet-x64-release-qemu_kvm',
      'x64-release',
      'garnet',
    ],
  ],
  const <List<String>>[
    const <String>[
      'zircon-arm64-clang-qemu_kvm',
      'arm64-clang',
      'zircon',
    ],
    const <String>[
      'zircon-arm64-gcc-qemu_kvm',
      'arm64-gcc',
      'zircon',
    ],
    const <String>[
      'zircon-x64-clang-qemu_kvm',
      'x64-clang',
      'zircon',
    ],
    const <String>[
      'zircon-x64-gcc-qemu_kvm',
      'x64-gcc',
      'zircon',
    ],
  ],
  const <List<String>>[
    const <String>[
      'web_view-x64-linux',
      'x64-linux',
      'web_view',
    ],
    const <String>[
      'web_view-arm64-linux',
      'arm64-linux',
      'web_view',
    ],
    const <String>[
      'jiri-x64-linux',
      'x64-linux',
      'jiri',
    ],
    const <String>[
      'jiri-x64-mac',
      'x64-mac',
      'jiri',
    ],
  ],
  const <List<String>>[
    const <String>[
      'zircon-roller',
      'zircon',
      'roller',
    ],
    const <String>[
      'garnet-roller',
      'garnet',
      'roller',
    ],
    const <String>[
      'peridot-roller',
      'peridot',
      'roller',
    ],
  ]
];

void main() {
  setupLogger();

  final BuildService buildService = new BuildService();

  final List<List<BuildStatusModel>> buildStatusModels =
      <List<BuildStatusModel>>[];

  for (List<List<String>> buildConfigs in _kTargetsMap) {
    List<BuildStatusModel> categoryModels = <BuildStatusModel>[];
    for (List<String> config in buildConfigs) {
      BuildStatusModel buildStatusModel = new BuildStatusModel(
        type: config[2],
        name: config[1],
        url: config[0],
        buildService: buildService,
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
      buildService: buildService,
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
