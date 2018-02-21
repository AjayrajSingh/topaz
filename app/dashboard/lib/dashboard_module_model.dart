// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:lib.app.dart/app.dart';
import 'package:lib.module.fidl/module_context.fidl.dart';
import 'package:lib.module.fidl._module_controller/module_controller.fidl.dart';
import 'package:lib.module.fidl._module_controller/module_state.fidl.dart';
import 'package:lib.story.fidl/link.fidl.dart';
import 'package:lib.surface.fidl/surface.fidl.dart';
import 'package:lib.user.fidl/device_map.fidl.dart';
import 'package:collection/collection.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/modular.dart';
import 'package:web_view/web_view.dart' as web_view;

import 'package:dashboard/build_status_model.dart';
import 'package:dashboard/chatter.dart';

/// Manages the framework FIDL services for this module.
class DashboardModuleModel extends ModuleModel implements TickerProvider {
  final DeviceMapProxy _deviceMapProxy = new DeviceMapProxy();

  /// The application context for this module.
  final ApplicationContext applicationContext;

  /// The models that get the various build statuses.
  final List<List<BuildStatusModel>> buildStatusModels;

  final DateTime _startTime = new DateTime.now();
  DateTime _lastRefreshed;
  List<String> _devices;
  ModuleWatcherBinding _webviewModuleWatcherBinding;
  ModuleControllerProxy _webviewModuleControllerProxy;
  LinkProxy _webviewLinkProxy;
  Timer _deviceMapTimer;
  Chatter _chatter;

  /// Constructor.
  DashboardModuleModel({this.applicationContext, this.buildStatusModels}) {
    // ignore: avoid_function_literals_in_foreach_calls
    buildStatusModels.expand((List<BuildStatusModel> models) => models).forEach(
          (BuildStatusModel buildStatusModel) =>
              buildStatusModel.addListener(_updatePassFailTime),
        );
  }

  @override
  void onReady(
    ModuleContext moduleContext,
    Link link,
  ) {
    super.onReady(moduleContext, link);
    _chatter = new Chatter(moduleContext);
  }

  @override
  void onStop() {
    closeWebView();
    _chatter.onStop();
    _deviceMapProxy.ctrl.close();
    _deviceMapTimer?.cancel();
    _deviceMapTimer = null;
    super.onStop();
  }

  @override
  Ticker createTicker(TickerCallback onTick) => new Ticker(onTick);

  /// The time the dashboard started.
  DateTime get startTime => _startTime;

  /// The time the dashboard was last refreshed.
  DateTime get lastRefreshed => _lastRefreshed;

  /// The devices for the current user.
  List<String> get devices => _devices;

  /// Launches the chat module.
  void launchChat() {
    _chatter.launchChat();
  }

  /// Closes the chat module.
  void closeChat() {
    _chatter.closeChat();
  }

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
    _deviceMapProxy.query((List<DeviceMapEntry> devices) {
      List<String> newDeviceList =
          devices.map((DeviceMapEntry entry) => entry.deviceId).toList();
      if (!const ListEquality<String>().equals(_devices, newDeviceList)) {
        _devices = new List<String>.unmodifiable(newDeviceList);
        notifyListeners();
      }
    });
  }

  /// Starts a web view module pointing to the given [buildName].
  void launchWebView(String buildName) {
    const String webViewLinkName = 'web_view';
    final String url =
        'https://luci-scheduler.appspot.com/jobs/fuchsia/$buildName';

    if (_webviewLinkProxy != null) {
      _webviewLinkProxy
        ..set(
          <String>[],
          JSON.encode(<String, Map<String, String>>{
            'view': <String, String>{'uri': url}
          }),
        );
      _webviewModuleControllerProxy.focus();
      return;
    }
    _webviewLinkProxy?.ctrl?.close();
    _webviewLinkProxy = new LinkProxy();

    moduleContext.getLink(webViewLinkName, _webviewLinkProxy.ctrl.request());
    _webviewLinkProxy
      ..set(
        <String>[],
        JSON.encode(<String, Map<String, String>>{
          'view': <String, String>{'uri': url}
        }),
      );

    _webviewModuleControllerProxy?.ctrl?.close();
    _webviewModuleControllerProxy = new ModuleControllerProxy();

    moduleContext.startModuleInShell(
      'module:web_view',
      web_view.kWebViewURL,
      webViewLinkName,
      null, // incomingServices,
      _webviewModuleControllerProxy.ctrl.request(),
      const SurfaceRelation(arrangement: SurfaceArrangement.copresent),
      true,
    );
    _webviewModuleWatcherBinding = new ModuleWatcherBinding();
    _webviewModuleControllerProxy.watch(
      _webviewModuleWatcherBinding.wrap(
        new _ModuleWatcherImpl(onStop: closeWebView),
      ),
    );
  }

  /// Closes a previously launched web view.
  void closeWebView() {
    _webviewModuleControllerProxy?.ctrl?.close();
    _webviewModuleControllerProxy = null;
    _webviewLinkProxy?.ctrl?.close();
    _webviewLinkProxy = null;
    _webviewModuleWatcherBinding?.close();
    _webviewModuleWatcherBinding = null;
  }

  void _updatePassFailTime() {
    _lastRefreshed = new DateTime.now();
    notifyListeners();
  }

  /// Wraps [ModelFinder.of] for this [Model]. See [ModelFinder.of] for more
  /// details.
  static DashboardModuleModel of(BuildContext context) =>
      new ModelFinder<DashboardModuleModel>().of(context);
}

class _ModuleWatcherImpl extends ModuleWatcher {
  final VoidCallback onStop;

  _ModuleWatcherImpl({this.onStop});

  @override
  void onStateChange(ModuleState newState) {
    /// If our module was stopped by the framework, notify this.
    if (newState == ModuleState.stopped || newState == ModuleState.done) {
      onStop();
    }
  }
}
