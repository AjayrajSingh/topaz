// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app.dart/app.dart';
import 'package:fidl_fidl_test_compatibility/fidl.dart';
import 'package:fidl/fidl.dart' show InterfaceRequest;
import 'package:fidl_fuchsia_sys/fidl.dart';

class EchoImpl implements Echo {
  final StartupContext context;

  // Saves references to proxies from which we're expecting events.
  Map<String, EchoProxy> proxies = {};

  EchoImpl(this.context);

  void proxyEcho(
      Struct value, String forwardToServer,
      void Function(Struct value) callback) {
    assert(forwardToServer.isNotEmpty);

    final Services services = new Services();
    final LaunchInfo launchInfo = new LaunchInfo(
        url: forwardToServer, directoryRequest: services.request());
    final ComponentControllerProxy controller = new ComponentControllerProxy();
    context.launcher.createComponent(launchInfo, controller.ctrl.request());
    final EchoProxy echo = new EchoProxy();
    services.connectToService(echo.ctrl);

    echo.echoStruct(value, '', callback);
  }

  @override
  void echoStruct(
      Struct value, String forwardToServer,
      void Function(Struct value) callback) {
    if (forwardToServer != null && forwardToServer.isNotEmpty) {
      proxyEcho(value, forwardToServer, callback);
    } else {
      callback(value);
    }
  }

  void handleEchoEvent(Struct value, String serverUrl) {
    _echoBinding.events.echoEvent(value);
    // Not technically safe if there's more than one outstanding event on this
    // proxy, but that shouldn't happen in the existing test.
    proxies.remove(serverUrl);
  }

  @override
  void echoStructNoRetVal(Struct value, String forwardToServer) {
    if (forwardToServer != null && forwardToServer.isNotEmpty) {
      final Services services = new Services();
      final LaunchInfo launchInfo = new LaunchInfo(
          url: forwardToServer, directoryRequest: services.request());
      final ComponentControllerProxy controller = new ComponentControllerProxy();
      context.launcher.createComponent(launchInfo, controller.ctrl.request());
      final EchoProxy echo = new EchoProxy();
      services.connectToService(echo.ctrl);
      // Keep echo around until we process the expected event.
      proxies[forwardToServer] = echo;
      echo
         ..echoEvent = (Struct val) { handleEchoEvent(val, forwardToServer); }
         ..echoStructNoRetVal(value, '');
    } else {
      _echoBinding.events.echoEvent(value);
    }
  }
}

final EchoBinding _echoBinding = new EchoBinding();

void main(List<String> args) {
  final StartupContext context = new StartupContext.fromStartupInfo();
  final EchoImpl echoImpl = new EchoImpl(context);
  context.outgoingServices.addServiceForName(
      (InterfaceRequest<Echo> request) => _echoBinding.bind(echoImpl, request),
      Echo.$serviceName);
}
