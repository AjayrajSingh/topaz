// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_sys/fidl.dart';
import 'package:fidl_fuchsia_testing_runner/fidl.dart';
import 'package:flutter/material.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';

const Color _lightColor = const Color(0xFF4dac26);
const Color _darkColor = const Color(0xFFd01c8b);
const int _gridSize = 6;
const String _testName = 'flutter_screencap';

TestRunnerProxy runnerProxy;
LauncherProxy launcherProxy;

/// Display a checker board pattern in red and green to verify that the
/// screen is displaying properly.
class CheckerBoard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    Size oneSize = new Size(size.width / _gridSize, size.height / _gridSize);
    List<Widget> rows = <Widget>[];
    for (int i = 0; i < _gridSize; i++) {
      List<Widget> boxes = <Widget>[];
      for (int j = 0; j < _gridSize; j++) {
        boxes.add(new Container(
          width: oneSize.width,
          height: oneSize.height,
          color: (i % 2) == (j % 2) ? _darkColor : _lightColor,
        ));
      }
      rows.add(new Row(
        children: boxes,
        mainAxisSize: MainAxisSize.max,
      ));
    }
    return new Column(
      mainAxisSize: MainAxisSize.max,
      children: rows,
    );
  }
}

void main() {
  setupLogger(
    name: 'flutter_screencap_test',
    logToStdoutForTest: true,
  );
  log.info('starting flutter screencap test');
  StartupContext startupContext = new StartupContext.fromStartupInfo();
  runApp(new MaterialApp(
    home: new CheckerBoard(),
  ));

  _reportTestResultsIfInTestHarness(startupContext.environmentServices);
}

void _reportTestResultsIfInTestHarness(
    ServiceProviderProxy environmentServices) {
  log.warning('_reportTestResultsIfInTestHarness()');
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
  log.info('runTestIterations()');
  Stopwatch stopWatch = new Stopwatch()..start();
  new Timer(const Duration(seconds: kDelayBeforeCaptureSeconds), () {
    LaunchInfo launchInfo =
        new LaunchInfo(url: 'fuchsia-pkg://fuchsia.com/screencap#meta/screencap.cmx', arguments: ['-histogram']);
    final ComponentControllerProxy controller = new ComponentControllerProxy();
    log.info('attempting to launch screencap');
    launcherProxy.createComponent(launchInfo, controller.ctrl.request());
    log.info('waiting for launch response');
    controller.onTerminated = (int r, _) {
      if (r == 0) {
        TestResult testResult = new TestResult(
          name: _testName,
          elapsed: stopWatch.elapsedMilliseconds,
          failed: false,
          message: 'success',
        );
        launcherProxy.ctrl.close();
        log.info('sending success test result');
        runnerProxy
          ..reportResult(testResult)
          ..teardown(() {
            runnerProxy.ctrl.close();
          });
        return;
      } else {
        _iterationAttempt++;
        if (_iterationAttempt >= kMaxAttempts) {
          log.info(
              'iteration attempts exceeded elapsed: ${stopWatch.elapsedMilliseconds}');
          TestResult testResult = new TestResult(
              name: _testName,
              elapsed: stopWatch.elapsedMilliseconds,
              failed: true,
              message: 'failed: See log for more info');
          launcherProxy.ctrl.close();
          log.info('sending failed test result');
          runnerProxy
            ..reportResult(testResult)
            ..teardown(() {
              runnerProxy.ctrl.close();
            });
          return;
        }

        // Try again
        log.info('try again');
        runTestIterations();
      }
    };
  });
}
