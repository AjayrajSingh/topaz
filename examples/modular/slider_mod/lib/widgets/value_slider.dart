// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../blocs/bloc_provider.dart';
import '../blocs/slider_bloc.dart';

class ValueSlider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bloc = BlocProvider.of<SliderBloc>(context);

    return StreamBuilder<double>(
        stream: bloc.valueStream,
        initialData: bloc.currentValue,
        builder: (BuildContext context, AsyncSnapshot<double> snapshot) {
          return Slider(
            max: bloc.maxValue,
            min: bloc.minValue,
            value: snapshot.data,
            onChanged: bloc.updateValue,
          );
        });
  }
}
