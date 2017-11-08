// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';

import 'module_model.dart';

/// The top-level widget of this module.
class Home extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Material(
      // The ScopedModelDescendant widget redraws the children whenever the
      // model calls notifyListeners(). Thus, it is the model's responsibility
      // to call notifyListeners() correctly, whenever the underlying data
      // changes and the UI has to be redrawn.
      child: new ScopedModelDescendant<CounterChildModuleModel>(
        builder: (
          BuildContext context,
          Widget child,
          CounterChildModuleModel model,
        ) {
          return new Center(
            // Show the current counter value, and buttons for changing the
            // counter value.
            child: new Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                new Text(
                  'Child Module',
                  style: new TextStyle(
                    fontWeight: FontWeight.bold,
                    height: 2.0,
                  ),
                ),
                const Text('Current Value:'),
                new Text(model.counter.toString()),
                new Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    new IconButton(
                      icon: new Icon(Icons.remove_circle_outline),
                      onPressed: model.decrement,
                    ),
                    new IconButton(
                      icon: new Icon(Icons.add_circle_outline),
                      onPressed: model.increment,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
