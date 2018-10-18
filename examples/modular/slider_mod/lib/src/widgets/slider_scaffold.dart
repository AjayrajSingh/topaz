// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../blocs/bloc_provider.dart';
import '../blocs/slider_bloc.dart';
import 'launch_bar.dart';
import 'value_slider.dart';

class SliderScaffold extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocProvider<SliderBloc>(
        bloc: SliderBloc(),
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
