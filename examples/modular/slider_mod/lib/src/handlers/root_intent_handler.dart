// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:example_modular_models/shape.dart';
import 'package:flutter/material.dart';
import 'package:fuchsia_modular/entity.dart';
import 'package:fuchsia_modular/module.dart';

import '../blocs/app_bloc.dart';
import '../blocs/bloc_provider.dart';
import '../widgets/slider_scaffold.dart';

class RootIntentHandler extends IntentHandler {
  @override
  void handleIntent(Intent intent) {
    // if (intent.action != '') {
    //   throw Exception('Unknown intent action');
    // }

    final shape = Shape(5.0);

    final shapeEntity = Entity(codec: ShapeCodec())..write(shape);

    runApp(
      MaterialApp(
        home: BlocProvider<AppBloc>(
          bloc: AppBloc(shapeEntity),
          child: SliderScaffold(shapeEntity, shape),
        ),
      ),
    );
  }
}
