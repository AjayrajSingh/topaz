// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:example_modular_models/shape.dart';
import 'package:flutter/material.dart' hide Intent;
import 'package:fuchsia_modular/entity.dart';
import 'package:fuchsia_modular/module.dart';
import 'package:meta/meta.dart';

import '../blocs/app_bloc.dart';
import '../blocs/bloc_provider.dart';
import 'slider_scaffold.dart';

class App extends StatefulWidget {
  final Stream<Intent> intentStream;

  const App({
    @required this.intentStream,
    Key key,
  })  : assert(intentStream != null),
        super(key: key);

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  StreamSubscription<Intent> _subscription;
  Entity _shapeEntity;
  Shape _shape;

  @override
  void initState() {
    super.initState();
    _subscription = widget.intentStream.listen(_handleIntent);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _handleIntent(Intent intent) async {
    if (_shape != null && _shapeEntity != null) {
      // already received our intent, no need to run again
      return;
    }

    final shape = Shape(5.0);
    final shapeEntity = await Module().createEntity(
      type: Shape.entityType,
      initialData: shape.toBytes(),
    );

    setState(() {
      _shape = shape;
      _shapeEntity = shapeEntity;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_shape != null && _shapeEntity != null) {
      return BlocProvider<AppBloc>(
        bloc: AppBloc(_shapeEntity),
        child: SliderScaffold(_shapeEntity, _shape),
      );
    } else {
      return Offstage();
    }
  }
}
