// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:application.lib.app.dart/app.dart';
import 'package:apps.modular.services.module/module_controller.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:apps.modular.services.user/device_map.fidl.dart';
import 'package:lib.widgets/modular.dart';
import 'package:web_view/web_view.dart' as web_view;

import 'build_status_model.dart';

class DashboardModuleModel extends ModuleModel {
  final DeviceMapProxy _deviceMapProxy = new DeviceMapProxy();

  final ApplicationContext applicationContext;
  final List<List<BuildStatusModel>> buildStatusModels;

  DateTime _startTime = new DateTime.now();
  DateTime _lastFailTime;
  DateTime _lastPassTime;
  DateTime _lastRefreshed;
  List<String> _devices;
  ModuleControllerProxy _moduleControllerProxy;

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
    super.onStop();
  }

  DateTime get startTime => _startTime;
  DateTime get lastFailTime => _lastFailTime;
  DateTime get lastPassTime => _lastPassTime;
  DateTime get lastRefreshed => _lastRefreshed;
  List<String> get devices => _devices;

  void loadDeviceMap() {
    connectToService(
      applicationContext.environmentServices,
      _deviceMapProxy.ctrl,
    );
    _deviceMapProxy.query((List<String> devices) {
      _devices = new List<String>.unmodifiable(devices);
      notifyListeners();
    });
  }

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

  void closeWebView() {
    _moduleControllerProxy?.ctrl?.close();
    _moduleControllerProxy = null;
  }

  void _updatePassFailTime() {
    if (buildStatusModels
        .expand((List<BuildStatusModel> models) => models)
        .every((BuildStatusModel model) =>
            model.buildStatus == BuildStatus.success)) {
      if (_lastPassTime == null) {
        _lastPassTime = new DateTime.now();
        _lastFailTime = null;
      }
    } else {
      if (_lastFailTime == null) {
        _lastFailTime = new DateTime.now();
        _lastPassTime = null;
      }
    }
    _lastRefreshed = new DateTime.now();
    notifyListeners();
  }
}
