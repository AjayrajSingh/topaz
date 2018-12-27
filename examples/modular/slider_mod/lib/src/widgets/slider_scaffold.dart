// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:example_modular_models/shape.dart';
import 'package:flutter/material.dart';
import 'package:fuchsia_modular/entity.dart';

import '../blocs/bloc_provider.dart';
import '../blocs/slider_bloc.dart';
import 'launch_bar.dart';
import 'value_slider.dart';

class SliderScaffold extends StatelessWidget {
  final Entity<Uint8List> shapeEntity;
  final Shape shape;

  const SliderScaffold(this.shapeEntity, this.shape);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocProvider<SliderBloc>(
        bloc: SliderBloc(shapeEntity, shape),
        child: Column(
          children: [
            Flexible(
              child: Container(
                color: Colors.blue,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LaunchBar(),
                  ],
                ),
              ),
            ),
            Flexible(
              child: Container(
                color: Colors.red,
                child: Column(
                  children: [
                    ValueSlider(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
