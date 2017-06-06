// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'loading_status.dart';

/// Color for default failure message
final Color _kFailureTextColor = Colors.grey[500];

/// Widget that renders the correct loading affordance based on the given
/// [LoadingStatus]
class Loader extends StatelessWidget {
  /// Current loading status
  final LoadingStatus loadingStatus;

  /// WidgetBuilder for the main content to show when the loading is completed
  final WidgetBuilder builder;

  /// Constructor
  Loader({
    Key key,
    @required this.loadingStatus,
    @required this.builder,
  })
      : super(key: key) {
    assert(loadingStatus != null);
    assert(builder != null);
  }

  @override
  Widget build(BuildContext context) {
    Widget output;
    switch (loadingStatus) {
      case LoadingStatus.inProgress:
        output = new Center(
          child: new CircularProgressIndicator(
            value: null,
            valueColor: new AlwaysStoppedAnimation<Color>(
              Colors.pink[500],
            ),
          ),
        );
        break;
      case LoadingStatus.failed:
        output = new Center(
          child: new Column(
            children: <Widget>[
              new Container(
                margin: const EdgeInsets.only(bottom: 8.0),
                child: new Icon(
                  Icons.sentiment_dissatisfied,
                  size: 48.0,
                  color: _kFailureTextColor,
                ),
              ),
              new Text(
                'Content failed to load',
                style: new TextStyle(
                  fontSize: 16.0,
                  color: _kFailureTextColor,
                ),
              ),
            ],
          ),
        );
        break;
      case LoadingStatus.completed:
        output = builder(context);
        break;
    }
    return output;
  }
}
