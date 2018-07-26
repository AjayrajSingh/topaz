// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:lib.widgets/model.dart';
import 'package:fidl_fuchsia_scpi/fidl.dart' as scpi;
import 'package:lib.app.dart/app.dart';

export 'package:lib.widgets/model.dart'
    show ScopedModel, Model, ScopedModelDescendant;

class SystemInfoModel extends Model {
  int _temperature = 0;
  int _fanLevel = 0;
  int _cpuUtilization = 0;
  int _memoryUtilization = 0;
  double _bigClusterFrequency = 0.0;
  double _littleClusterFrequency = 0.0;
  double _bigClusterVoltage = 0.0;
  double _littleClusterVoltage = 0.0;

  List<scpi.DvfsOpp> _bigClusterOpps;
  List<scpi.DvfsOpp> _smallClusterOpps;

  static const Duration _systemInformationUpdatePeriod = const Duration(seconds: 4);

  final scpi.SystemControllerProxy _systemControllerProxy = scpi.SystemControllerProxy();

  SystemInfoModel() {
    StartupContext startupContext = StartupContext.fromStartupInfo();
    connectToService(startupContext.environmentServices, _systemControllerProxy.ctrl);

    int powerDomain = 0;
    _systemControllerProxy.getDvfsInfo(powerDomain, (scpi.Status status, List<scpi.DvfsOpp> opps) {
      _bigClusterOpps = opps;
    });

    powerDomain = 1;
    _systemControllerProxy.getDvfsInfo(powerDomain, (scpi.Status status, List<scpi.DvfsOpp> opps) {
      _smallClusterOpps = opps;
    });

    _updateSysInformation();

    Timer.periodic(_systemInformationUpdatePeriod, (_) {
      _updateSysInformation();
    });
  }

  int get cpuUtilization => _cpuUtilization;
  int get memoryUtilization => _memoryUtilization;
  int get fanLevel => _fanLevel;
  int get temperature => _temperature;
  double get bigClusterFrequency => _bigClusterFrequency;
  double get littleClusterFrequency => _littleClusterFrequency;
  double get bigClusterVoltage => _bigClusterVoltage;
  double get littleClusterVoltage => _littleClusterVoltage;

  void _update() {
    notifyListeners();
  }

  void _updateSysInformation() {
    _systemControllerProxy.getSystemStatus((scpi.Status status, scpi.SystemStatus systemStatus) {
      _temperature = systemStatus.temperature;
      _fanLevel = systemStatus.fanLevel;
      _bigClusterFrequency =
        (_bigClusterOpps[systemStatus.bigClusterOpIndex].freqHz)/1000000000;
      _littleClusterFrequency =
        (_smallClusterOpps[systemStatus.smallClusterOpIndex].freqHz)/1000000000;
      _bigClusterVoltage =
        (_bigClusterOpps[systemStatus.bigClusterOpIndex].voltMv)/1000;
      _littleClusterVoltage =
        (_smallClusterOpps[systemStatus.smallClusterOpIndex].voltMv)/1000;
      _cpuUtilization = systemStatus.cpuUtilization;
      _memoryUtilization = systemStatus.memoryUtilization;
      _update();
    });
  }

}
