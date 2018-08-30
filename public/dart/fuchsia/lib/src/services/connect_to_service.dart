// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_sys/fidl_async.dart';
import 'package:fidl/fidl.dart';
import 'package:zircon/zircon.dart';

/// Registers the service connection specified by the [controller] argument
/// with the given [serviceProvider].
Future<void> connectToService<T>(
    ServiceProvider serviceProvider, AsyncProxyController<T> controller) async {
  final String serviceName = controller.$serviceName;
  if (serviceName == null) {
    throw Exception("${controller.$interfaceName}'s controller.\$serviceName"
        ' must not be null. Check the FIDL file for a missing [Discoverable]');
  }

  // we need to await here because the fidl bindings generate a signature
  // of type Future<Null> which differs from the Future<void> that we return.
  await serviceProvider.connectToService(
      serviceName, controller.request().passChannel());
}

/// Returns an [InterfaceHandle] for a connection to a service specified
/// by [serviceName]. The [serviceName] must be non-null and non-empty or
/// an exception will be thrown.
InterfaceHandle<T> connectToServiceByName<T>(
    ServiceProvider serviceProvider, String serviceName) {
  if (serviceName == null || serviceName.isEmpty) {
    throw Exception(
        'serviceName must not be null or empty in call to connectToServiceByName');
  }

  final ChannelPair pair = ChannelPair();
  serviceProvider.connectToService(serviceName, pair.first);
  return InterfaceHandle<T>(pair.second);
}
