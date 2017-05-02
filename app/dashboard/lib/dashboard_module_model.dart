// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:application.lib.app.dart/app.dart';
import 'package:application.services/service_provider.fidl.dart';
import 'package:apps.modular.services.module/module_context.fidl.dart';
import 'package:apps.modular.services.module/module_controller.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:apps.modular.services.user/device_map.fidl.dart';
import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:collection/collection.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/modular.dart';
import 'package:web_view/web_view.dart' as web_view;

import 'build_status_model.dart';
import 'chatter.dart';

/// Manages the framework FIDL services for this module.
class DashboardModuleModel extends ModuleModel implements TickerProvider {
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
  bool _showChat = false;
  ChildViewConnection _chatChildViewConnection;
  Chatter _chatter;
  AnimationController _transitionAnimation;
  CurvedAnimation _curvedTransitionAnimation;

  /// Constructor.
  DashboardModuleModel({this.applicationContext, this.buildStatusModels}) {
    buildStatusModels.expand((List<BuildStatusModel> models) => models).forEach(
          (BuildStatusModel buildStatusModel) =>
              buildStatusModel.addListener(_updatePassFailTime),
        );
    _transitionAnimation = new AnimationController(
      value: 0.0,
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _curvedTransitionAnimation = new CurvedAnimation(
      parent: _transitionAnimation,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.fastOutSlowIn,
    );
  }

  @override
  void onReady(
    ModuleContext moduleContext,
    Link link,
    ServiceProvider incomingServiceProvider,
  ) {
    super.onReady(moduleContext, link, incomingServiceProvider);
    _chatter = new Chatter(moduleContext);
    _chatter.load().then((ChildViewConnection childViewConnection) {
      _chatChildViewConnection = childViewConnection;
      notifyListeners();
    });
  }

  @override
  void onStop() {
    _chatter.onStop();
    _moduleControllerProxy?.ctrl?.close();
    _moduleControllerProxy = null;
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

  /// Indicates the chat module should be shown.
  bool get showChat => _showChat;

  /// The connection to use for showing the chat module.
  ChildViewConnection get chatChildViewConnection => _chatChildViewConnection;

  /// THe animation for showing and hiding the chat module.
  CurvedAnimation get animation => _curvedTransitionAnimation;

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

  /// Starts a web view module pointing to the given [url].
  void launchWebView(String url) {
    LinkProxy linkProxy = new LinkProxy();
    const String webViewLinkName = 'web_view';
    moduleContext.getLink(webViewLinkName, linkProxy.ctrl.request());
    linkProxy
      ..set(
        <String>[],
        JSON.encode(<String, Map<String, String>>{
          'view': <String, String>{'uri': url}
        }),
      )
      ..ctrl.close();

    _moduleControllerProxy?.ctrl?.close();
    _moduleControllerProxy = new ModuleControllerProxy();

    moduleContext.startModuleInShell(
      '',
      web_view.kWebViewURL,
      webViewLinkName,
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

  /// Toggles the showing of the chat module.
  void toggleChat() {
    _showChat = !_showChat;
    if (_showChat) {
      _transitionAnimation.forward();
    } else {
      _transitionAnimation.reverse();
    }
    notifyListeners();
  }

  void _updatePassFailTime() {
    _lastRefreshed = new DateTime.now();
    notifyListeners();
  }
}
