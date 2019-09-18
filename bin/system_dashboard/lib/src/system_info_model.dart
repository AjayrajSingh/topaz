// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:lib.widgets/model.dart';
import 'package:fidl_fuchsia_scpi/fidl_async.dart' as scpi;
import 'package:fuchsia_services/services.dart';

export 'package:lib.widgets/model.dart'
    show ScopedModel, Model, ScopedModelDescendant;

class SystemInfoModel extends Model {
  // Temperature in degrees Celsius.
  double _temperature = 0.0;
  int _fanLevel = 0;
  int _cpuUtilization = 0;
  int _memoryUtilization = 0;
  double _bigClusterFrequency = 0.0;
  double _littleClusterFrequency = 0.0;
  double _bigClusterVoltage = 0.0;
  double _littleClusterVoltage = 0.0;

  List<scpi.DvfsOpp> _bigClusterOpps;
  List<scpi.DvfsOpp> _smallClusterOpps;

  static const Duration _systemInformationUpdatePeriod = Duration(seconds: 4);

  final scpi.SystemControllerProxy _systemControllerProxy =
      scpi.SystemControllerProxy();

  SystemInfoModel() {
    StartupContext.fromStartupInfo()
        .incoming
        .connectToService(_systemControllerProxy);

    int powerDomain = 0;
    _systemControllerProxy.getDvfsInfo(powerDomain).then((result) {
      _bigClusterOpps = result.opps;
    });

    powerDomain = 1;
    _systemControllerProxy.getDvfsInfo(powerDomain).then((result) {
      _smallClusterOpps = result.opps;
    });

    _updateSysInformation();

    Timer.periodic(_systemInformationUpdatePeriod, (_) {
      _updateSysInformation();
    });
  }

  int get cpuUtilization => _cpuUtilization;
  int get memoryUtilization => _memoryUtilization;
  int get fanLevel => _fanLevel;
  double get temperature => _temperature;
  double get bigClusterFrequency => _bigClusterFrequency;
  double get littleClusterFrequency => _littleClusterFrequency;
  double get bigClusterVoltage => _bigClusterVoltage;
  double get littleClusterVoltage => _littleClusterVoltage;

  void _update() {
    notifyListeners();
  }

  void _updateSysInformation() {
    _systemControllerProxy.getSystemStatus().then((result) {
      final systemStatus = result.sysStatus;
      _temperature = systemStatus.temperatureCelsius;
      _fanLevel = systemStatus.fanLevel;
      _bigClusterFrequency =
          (_bigClusterOpps[systemStatus.bigClusterOpIndex].freqHz) / 1000000000;
      _littleClusterFrequency =
          (_smallClusterOpps[systemStatus.smallClusterOpIndex].freqHz) /
              1000000000;
      _bigClusterVoltage =
          (_bigClusterOpps[systemStatus.bigClusterOpIndex].voltUv) / 1000000;
      _littleClusterVoltage =
          (_smallClusterOpps[systemStatus.smallClusterOpIndex].voltUv) / 1000000;
      _cpuUtilization = systemStatus.cpuUtilization;
      _memoryUtilization = systemStatus.memoryUtilization;
      _update();
    });
  }
}
