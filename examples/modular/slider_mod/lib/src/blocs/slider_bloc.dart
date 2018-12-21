// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:example_modular_models/shape.dart';
import 'package:fuchsia_modular/entity.dart';

import 'bloc_provider.dart';

/// The [SliderBloc] provides actions and streams associated with
/// the onscreen slider.
class SliderBloc implements BlocBase {
  final Entity<Shape> shapeEntity;
  final Shape shape;

  final _valueController = StreamController<double>.broadcast();

  final double minValue = 0.0;

  final double maxValue = 10.0;
  SliderBloc(this.shapeEntity, this.shape);

  double get currentValue => shape.size;
  Stream<double> get valueStream => _valueController.stream;

  @override
  void dispose() {
    _valueController.close();
  }

  void updateValue(double newValue) {
    _valueController.add(newValue);
    shape.size = newValue;

    shapeEntity.write(shape);
  }
}
