// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'bloc_provider.dart';

/// The [SliderBloc] provides actions and streams associated with
/// the onscreen slider.
class SliderBloc implements BlocBase {
  final _valueController = StreamController<double>.broadcast();
  double _lastKnownValue = 3.0;

  final double minValue = 0.0;
  final double maxValue = 10.0;

  Stream<double> get valueStream => _valueController.stream;
  double get currentValue => _lastKnownValue;

  void updateValue(double newValue) {
    _lastKnownValue = newValue;
    _valueController.add(newValue);
  }

  @override
  void dispose() {
    _valueController.close();
  }
}
