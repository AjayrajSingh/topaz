// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lib.run_mod.dart/run_mod.dart';
import 'package:lib.widgets.dart/model.dart';
import 'package:meta/meta.dart';

/// Main

void main() {
  runMod(
    child: _loadConfig().then((String apiKey) {
      // Create the Api object with the config key
      Api api = new Api(
        apiKey: apiKey,
      );

      // Create the model object with the Api
      MyModel model = new MyModel(
        textFetcher: api.fetchText,
      );

      return new MaterialApp(
        home: new ScopedModel<MyModel>(
          model: model,
          child: new _MyScaffold(),
        ),
      );
    }),
  );
}

Future<String> _loadConfig() async {
  Completer<String> c = new Completer<String>();
  new Timer(const Duration(seconds: 3), () {
    c.complete('api-key');
  });

  return c.future;
}

/// API
class Api {
  final String apiKey;

  int _counter = 0;

  Api({
    @required this.apiKey,
  }) : assert(apiKey != null);

  Future<String> fetchText() async {
    int localCounter = _counter++;

    /// simulate connecting to an external api
    Completer<String> c = new Completer<String>();
    new Timer(const Duration(seconds: 3), () {
      c.complete('$localCounter');
    });

    return c.future;
  }
}

typedef Future<String> TextFetcher();

/// Models
class MyModel extends Model {
  final TextFetcher textFetcher;

  MyModel({
    @required this.textFetcher,
  }) : assert(textFetcher != null);

  String _subText;
  String get subText => _subText ?? '';

  void updateSubText() {
    textFetcher().then((String t) {
      _subText = t;
      notifyListeners();
    });
  }
}

/// Widget
class _MyScaffold extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      body: new ScopedModelDescendant<MyModel>(builder: (
        BuildContext context,
        Widget child,
        MyModel model,
      ) {
        return new Center(
          child: new Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              new Text(model.subText),
              new RaisedButton(
                onPressed: model.updateSubText,
              ),
            ],
          ),
        );
      }),
    );
  }
}
