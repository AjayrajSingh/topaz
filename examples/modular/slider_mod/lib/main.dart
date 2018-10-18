// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:fuchsia_modular/module.dart';
import 'src/blocs/app_bloc.dart';
import 'src/blocs/bloc_provider.dart';
import 'src/widgets/slider_scaffold.dart';

void main() {

  // TODO replace the existing code with this line when MF-19 is fixed
  // Module().registerIntentHandler(RootIntentHandler());

  Module();
  runApp(
    MaterialApp(
      home: BlocProvider<AppBloc>(
        bloc: AppBloc(),
        child: SliderScaffold(),
      ),
    ),
  );
}
