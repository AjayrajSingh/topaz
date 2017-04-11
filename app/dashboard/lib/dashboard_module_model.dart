// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:application.lib.app.dart/app.dart';
import 'package:apps.modular.services.module/module_controller.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:apps.modular.services.user/device_map.fidl.dart';
import 'package:collection/collection.dart';
import 'package:lib.widgets/modular.dart';
import 'package:web_view/web_view.dart' as web_view;

import 'build_status_model.dart';

/// Manages the framework FIDL services for this module.
class DashboardModuleModel extends ModuleModel {
  final DeviceMapProxy _deviceMapProxy = new DeviceMapProxy();

  /// The application context for this module.
  final ApplicationContext applicationContext;

  /// The models that get the various build statuses.
  final List<List<BuildStatusModel>> buildStatusModels;

  DateTime _startTime = new DateTime.now();
  DateTime _lastRefreshed;
  List<String> _devices;
  ModuleControllerProxy _moduleControllerProxy;
  Timer _deviceMapTimer;

  /// Constructor.
  DashboardModuleModel({this.applicationContext, this.buildStatusModels}) {
    buildStatusModels.expand((List<BuildStatusModel> models) => models).forEach(
          (BuildStatusModel buildStatusModel) =>
              buildStatusModel.addListener(_updatePassFailTime),
        );
  }

  @override
  void onStop() {
    _moduleControllerProxy?.ctrl?.close();
    _moduleControllerProxy = null;
    _deviceMapProxy.ctrl.close();
    _deviceMapTimer?.cancel();
    _deviceMapTimer = null;
    super.onStop();
  }

  /// The time the dashboard started.
  DateTime get startTime => _startTime;

  /// The time the dashboard was last refreshed.
  DateTime get lastRefreshed => _lastRefreshed;

  /// The devices for the current user.
  List<String> get devices => _devices;

  /// Starts loading the device map from the environment.
  void loadDeviceMap() {
    connectToService(
      applicationContext.environmentServices,
      _deviceMapProxy.ctrl,
    );
    _deviceMapTimer?.cancel();
    _deviceMapTimer = new Timer.periodic(
        const Duration(seconds: 30), (_) => _queryDeviceMap());
  }

  void _queryDeviceMap() {
    _deviceMapProxy.query((List<String> devices) {
      if (!const ListEquality<String>().equals(_devices, devices)) {
        _devices = new List<String>.unmodifiable(devices);
        notifyListeners();
      }
    });
  }

  /// Starts a web view module pointing to the given [url].
  void launchWebView(String url) {
    LinkProxy linkProxy = new LinkProxy();
    moduleContext.createLink('', linkProxy.ctrl.request());
    linkProxy.set(<String>[], JSON.encode(<String, String>{"url": url}));

    _moduleControllerProxy?.ctrl?.close();
    _moduleControllerProxy = new ModuleControllerProxy();

    moduleContext.startModuleInShell(
      '',
      web_view.kWebViewURL,
      linkProxy.ctrl.unbind(),
      null,
      null,
      _moduleControllerProxy.ctrl.request(),
      '',
    );
  }

  /// Closes a previously launched web view.
  void closeWebView() {
    _moduleControllerProxy?.ctrl?.close();
    _moduleControllerProxy = null;
  }

  void _updatePassFailTime() {
    _lastRefreshed = new DateTime.now();
    notifyListeners();
  }
}
