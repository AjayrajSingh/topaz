// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_fidl_examples_echo/fidl_async.dart' as fidl_echo;
import 'package:lib.app.dart/app_async.dart';

bool _quiet = false;

class _EchoImpl extends fidl_echo.Echo {
  final _binding = fidl_echo.EchoBinding();

  void bind(InterfaceRequest<fidl_echo.Echo> request) {
    _binding.bind(this, request);
  }

  @override
  Future<String> echoString(String value) async {
    if (!_quiet) {
      print('EchoString: $value');
    }
    return value;
  }
}

void main(List<String> args) {
  _quiet = args.contains('-q');

  final context = StartupContext.fromStartupInfo();
  final echo = _EchoImpl();

  context.outgoingServices.addServiceForName<fidl_echo.Echo>(
      echo.bind, fidl_echo.Echo.$serviceName);
}
