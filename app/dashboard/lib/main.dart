// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:fidl_fuchsia_sys/fidl.dart';
import 'package:fidl_fuchsia_testing_runner/fidl.dart';
import 'package:flutter/material.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.widgets.dart/model.dart';
import 'package:lib.widgets/widgets.dart';

import 'build_status_model.dart';
import 'dashboard_app.dart';
import 'dashboard_model.dart';
import 'service/build_service.dart';

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
      'arm64-release',
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
      'jiri',
      'jiri',
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

const String _kLastUpdate = '/system/data/build/last-update';
const String _testName = 'dashboard_boot_test';

TestRunnerProxy runnerProxy;
LauncherProxy launcherProxy;

final List<List<BuildStatusModel>> _buildStatusModels =
    <List<BuildStatusModel>>[];

ModuleDriver _driver;

void main() {
  setupLogger();

  DateTime buildTimestamp;
  File lastUpdateFile = new File(_kLastUpdate);
  if (lastUpdateFile.existsSync()) {
    String lastUpdate = lastUpdateFile.readAsStringSync();
    log.info('Build timestamp: ${lastUpdate.trim()}');
    try {
      buildTimestamp = DateTime.parse(lastUpdate.trim());
    } on FormatException {
      log.warning('Could not parse build timestamp! ${lastUpdate.trim()}');
    }
  }

  final BuildService buildService = new BuildService();

  for (List<List<String>> buildConfigs in _kTargetsMap) {
    List<BuildStatusModel> categoryModels = <BuildStatusModel>[];
    for (List<String> config in buildConfigs) {
      BuildStatusModel buildStatusModel = new BuildStatusModel(
        type: config[2],
        name: config[1],
        url: config[0],
        buildService: buildService,
        modelRowsCount: _buildStatusModels.length,
      )..start();
      categoryModels.add(buildStatusModel);
    }
    _buildStatusModels.add(categoryModels);
  }

  StartupContext startupContext = new StartupContext.fromStartupInfo();

  final dashboardModel = new DashboardModel(
    buildStatusModels: _buildStatusModels,
    launchWebview: _launchWebview,
  );

  _driver = new ModuleDriver(onTerminate: dashboardModel.onStop);

  runApp(
    MaterialApp(
      title: 'Fuchsia Build Status',
      theme: new ThemeData(primaryColor: kFuchsiaColor),
      home: new WindowMediaQuery(
        onWindowMetricsChanged: () {
          _buildStatusModels
              .expand((List<BuildStatusModel> models) => models)
              // ignore: avoid_function_literals_in_foreach_calls
              .forEach((BuildStatusModel model) =>
                  model.onWindowMetricsChanged(_buildStatusModels.length));
        },
        child: new ScopedModel<DashboardModel>(
          model: dashboardModel,
          child: new DashboardApp(
            buildService: buildService,
            buildStatusModels: _buildStatusModels,
            buildTimestamp: buildTimestamp,
            onRefresh: onRefresh,
            onLaunchUrl: dashboardModel.launchWebView,
          ),
        ),
      ),
    ),
  );

  _driver.start().then((_) {
    dashboardModel.loadDeviceMap(startupContext);
  }).catchError(log.severe);

  _reportTestResultsIfInTestHarness(startupContext.environmentServices);
}

void onRefresh() {
  _buildStatusModels
      .expand((List<BuildStatusModel> models) => models)
      // ignore: avoid_function_literals_in_foreach_calls
      .forEach((BuildStatusModel model) => model.refresh());
}

Future<ModuleControllerClient> _launchWebview(Intent intent) async {
  return _driver.startModule(
    intent: intent,
    name: 'module:web_view',
    surfaceRelation:
        const SurfaceRelation(arrangement: SurfaceArrangement.copresent),
  );
}

void _reportTestResultsIfInTestHarness(
    ServiceProviderProxy environmentServices) {
  runnerProxy = new TestRunnerProxy();
  try {
    connectToService(environmentServices, runnerProxy.ctrl);
    runnerProxy.identify(_testName, () {});
    try {
      launcherProxy = new LauncherProxy();
      connectToService(environmentServices, launcherProxy.ctrl);

      runTestIterations();
    } on Exception catch (e) {
      log.warning('Not able to launch. Not enabling test mode: $e');
      runnerProxy.teardown(() {
        runnerProxy.ctrl.close();
      });
    }
  } on Exception catch (e) {
    log.warning('Not in automated test. Using normal mode: $e');
  }
}

const int kMaxAttempts = 3;
const int kDelayBeforeCaptureSeconds = 7;

int _iterationAttempt = 0;

void runTestIterations() {
  Stopwatch stopWatch = new Stopwatch()..start();
  new Timer(const Duration(seconds: kDelayBeforeCaptureSeconds), () {
    LaunchInfo launchInfo =
        new LaunchInfo(url: 'screencap', arguments: ['-histogram']);
    final ComponentControllerProxy controller = new ComponentControllerProxy();
    launcherProxy.createComponent(launchInfo, controller.ctrl.request());
    controller.onTerminated = (int r, _) {
      if (r == 0) {
        log.info('elapsed: ${stopWatch.elapsedMilliseconds}');
        TestResult testResult = new TestResult(
          name: _testName,
          elapsed: stopWatch.elapsedMilliseconds,
          failed: false,
          message: 'success',
        );
        launcherProxy.ctrl.close();
        runnerProxy
          ..reportResult(testResult)
          ..teardown(() {
            runnerProxy.ctrl.close();
          });
        return;
      } else {
        _iterationAttempt++;
        if (_iterationAttempt >= kMaxAttempts) {
          log.info('elapsed: ${stopWatch.elapsedMilliseconds}');
          TestResult testResult = new TestResult(
              name: _testName,
              elapsed: stopWatch.elapsedMilliseconds,
              failed: true,
              message: 'failed: See log for more info');
          launcherProxy.ctrl.close();
          runnerProxy
            ..reportResult(testResult)
            ..teardown(() {
              runnerProxy.ctrl.close();
            });
          return;
        }

        // Try refreshing the screen captures and comparing again
        onRefresh();
        runTestIterations();
      }
    };
  });
}
