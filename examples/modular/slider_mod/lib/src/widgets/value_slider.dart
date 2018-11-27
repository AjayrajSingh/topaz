// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:fuchsia/services.dart';
import 'package:fidl_fuchsia_fibonacci/fidl_async.dart' as fidl_fib;

import '../blocs/bloc_provider.dart';
import '../blocs/fibonacci_bloc.dart';
import '../blocs/slider_bloc.dart';

class ValueSlider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sliderBloc = BlocProvider.of<SliderBloc>(context);
    final fibBloc = FibonacciBloc();

    return Column(
      children: <Widget>[
        StreamBuilder<double>(
            stream: sliderBloc.valueStream,
            initialData: sliderBloc.currentValue,
            builder: (BuildContext context, AsyncSnapshot<double> snapshot) {
              return Column(
                children: <Widget>[
                  Slider(
                    max: sliderBloc.maxValue,
                    min: sliderBloc.minValue,
                    value: snapshot.data,
                    onChanged: sliderBloc.updateValue,
                  ),
                  Container(
                    alignment: Alignment.center,
                    child: new Text('Value: ${snapshot.data.toInt()}',
                        style: Theme.of(context).textTheme.display1),
                  ),
                ],
              );
            }),
        RaisedButton(
          child: Text('Calc Fibonacci'),
          onPressed: () {
            // connect to fib agent
            final _proxy = fidl_fib.FibonacciServiceProxy();
            connectToAgentService('fibonacci_agent', _proxy);
            // calculate fib number
            _proxy
                .calcFibonacci(sliderBloc.currentValue.toInt())
                .then(fibBloc.updateValue);
          },
        ),
        Container(
          alignment: Alignment.center,
          child: _buildFibResultWidget(fibBloc),
        ),
      ],
    );
  }

  StreamBuilder<int> _buildFibResultWidget(FibonacciBloc fibBloc) {
    return StreamBuilder<int>(
        stream: fibBloc.valueStream,
        initialData: fibBloc.currentValue,
        builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
          if (snapshot.data == 0) {
            // don't display anything
            return Offstage();
          } else {
            return Container(
              alignment: Alignment.center,
              child: new Text('Result: ${snapshot.data}',
                  style: Theme.of(context).textTheme.display1),
              key: Key('fib-result-widget-key'),
            );
          }
        });
  }
}
