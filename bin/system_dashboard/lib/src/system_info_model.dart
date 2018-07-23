// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:lib.widgets/model.dart';
import 'package:meta/meta.dart';

export 'package:lib.widgets/model.dart'
    show ScopedModel, Model, ScopedModelDescendant;

class SystemInfoModel extends Model {
  int _temperature = 50;
  int _fanLevel = 1;
  int _cpuUtilization = 30;
  double _bigClusterFrequency = 1.2;
  double _littleClusterFrequency = 1.0;
  double _bigClusterVoltage = 1.29;
  double _littleClusterVoltage = 0.91;

  static const Duration _systemInformationUpdatePeriod = const Duration(seconds: 5);
  static const Duration _cpuUtilizationUpdatePeriod = const Duration(seconds: 2);

  SystemInfoModel() {
    Timer.periodic(_systemInformationUpdatePeriod, (_) {
      _updateSysInformation();
    });

    Timer.periodic(_cpuUtilizationUpdatePeriod, (_) {
      _updateCpuUtilization();
    });
  }

  int get cpuUtil => _cpuUtilization;
  int get fanLevel => _fanLevel;
  int get temperature => _temperature;
  double get bigClusterFrequency => _bigClusterFrequency;
  double get littleClusterFrequency => _littleClusterFrequency;
  double get bigClusterVoltage => _bigClusterVoltage;
  double get littleClusterVoltage => _littleClusterVoltage;

  void _setSysInfo(
      {@required double bigClusterFrequency,
      @required double littleClusterFrequency,
      @required double bigClusterVoltage,
      @required double littleClusterVoltage,
      @required int temperature,
      @required int fanLevel}) {

    _bigClusterFrequency = bigClusterFrequency;
    _littleClusterFrequency = littleClusterFrequency;
    _bigClusterVoltage = bigClusterVoltage;
    _littleClusterVoltage = littleClusterVoltage;
    _temperature = temperature;
    _fanLevel = fanLevel;
    notifyListeners();
  }

  void _setCpuUtilization(int utilization) {
    _cpuUtilization = utilization;
    notifyListeners();
  }

  void _updateSysInformation() {
    // TODO: (braval) READ system info using FIDL interface
    _temperature++;
    _setSysInfo(
        bigClusterFrequency: _bigClusterFrequency,
        littleClusterFrequency: _littleClusterFrequency,
        bigClusterVoltage: _bigClusterVoltage,
        littleClusterVoltage: _littleClusterVoltage,
        temperature: _temperature,
        fanLevel: _fanLevel);
  }

  void _updateCpuUtilization() {
    // TODO: (braval) READ the CPU Utilization and display here
    _cpuUtilization = (_cpuUtilization + 6) % 100;
    _setCpuUtilization(_cpuUtilization);
  }
}
