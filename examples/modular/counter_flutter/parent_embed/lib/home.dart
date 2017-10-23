// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.ui.flutter/child_view.dart';
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
      child: new ScopedModelDescendant<CounterParentModuleModel>(
        builder: (
          BuildContext context,
          Widget child,
          CounterParentModuleModel model,
        ) {
          // Main content of this parent module, which shows the current counter
          // value, and buttons for changing the counter value.
          final Widget content = new Center(
            child: new Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                new Text(
                  'Parent Module - Embed',
                  style: new TextStyle(
                    fontWeight: FontWeight.bold,
                    height: 2.0,
                  ),
                ),
                new Text('Current Value:'),
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

          // If the ChildViewConnection is provided by the model (i.e., when the
          // child module has been successfully started), layout the parent
          // content and the child view side by side with a Row widget.
          if (model.connection != null) {
            return new Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                new Expanded(
                  child: new Container(
                    child: content,
                    // Give blue background to the parent content.
                    color: Colors.blue[100],
                  ),
                ),
                new Expanded(
                  child: new ChildView(connection: model.connection),
                ),
              ],
            );
          } else {
            // Otherwise, just show the parent content.
            return content;
          }
        },
      ),
    );
  }
}
