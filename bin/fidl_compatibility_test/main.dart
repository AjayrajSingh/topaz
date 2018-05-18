// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app.dart/app.dart';
import 'package:fidl_compatibility_test_service/fidl.dart';
import 'package:fidl/fidl.dart' show InterfaceRequest;
import 'package:fidl_component/fidl.dart';

class EchoImpl implements Echo {
  final ApplicationContext context;

  EchoImpl(this.context);

  void proxyEcho(Struct value, void Function(Struct value) callback) {
    assert(value.forwardToServer.isNotEmpty);

    final Services services = new Services();
    final LaunchInfo launchInfo = new LaunchInfo(
        url: value.forwardToServer, directoryRequest: services.request());
    final ApplicationControllerProxy controller =
        new ApplicationControllerProxy();
    context.launcher.createApplication(launchInfo, controller.ctrl.request());

    final Struct newValue = new Struct(
      primitiveTypes: value.primitiveTypes,
      defaultValues: value.defaultValues,
      arrays: value.arrays,
      arrays2d: value.arrays2d,
      vectors: value.vectors,
      handles: value.handles,
      strings: value.strings,
      defaultEnum: value.defaultEnum,
      i8Enum: value.i8Enum,
      i16Enum: value.i16Enum,
      i32Enum: value.i32Enum,
      i64Enum: value.i64Enum,
      u8Enum: value.u8Enum,
      u16Enum: value.u16Enum,
      u32Enum: value.u32Enum,
      u64Enum: value.u64Enum,
      structs: value.structs,
      unions: value.unions,
      b: value.b,
      forwardToServer: null,
    );

    final EchoProxy echo = new EchoProxy();
    services.connectToService(echo.ctrl);

    echo.echoStruct(newValue, callback);
  }

  @override
  void echoStruct(Struct value, void Function(Struct value) callback) {
    if (value.forwardToServer != null && value.forwardToServer.isNotEmpty) {
      proxyEcho(value, callback);
    } else {
      callback(value);
    }
  }
}

final EchoBinding _echoBinding = new EchoBinding();

void main(List<String> args) {
  final ApplicationContext context = new ApplicationContext.fromStartupInfo();
  final EchoImpl echoImpl = new EchoImpl(context);
  context.outgoingServices.addServiceForName(
      (InterfaceRequest<Echo> request) => _echoBinding.bind(echoImpl, request),
      Echo.$serviceName);
}
