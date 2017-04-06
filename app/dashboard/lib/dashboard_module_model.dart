// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:apps.modular.services.user/device_map.fidl.dart';
import 'package:lib.widgets/modular.dart';

class DashboardModuleModel extends ModuleModel {
  final DeviceMapProxy _deviceMapProxy = new DeviceMapProxy();

  final ApplicationContext applicationContext;

  DashboardModuleModel({this.applicationContext});
  void loadDeviceMap() {
    connectToService(
      applicationContext.environmentServices,
      _deviceMapProxy.ctrl,
    );
    _deviceMapProxy.query((List<String> devices) {
      print('devices: $devices');
    });
  }
}
