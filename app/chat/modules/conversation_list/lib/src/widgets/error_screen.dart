// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// Error screen to be shown when there is an unrecoverable error.
class ErrorScreen extends StatelessWidget {
  /// Creates a new [ErrorScreen].
  const ErrorScreen({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new Material(
      color: Colors.grey[200],
      child: new Center(
        child: new Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            new Icon(
              Icons.error,
              color: Colors.grey[600],
              size: 128.0,
            ),
            new Container(height: 16.0),
            new Text(
              'Failed to initialize',
              style: new TextStyle(
                color: Colors.grey[600],
                fontSize: 36.0,
              ),
            ),
            new Container(height: 4.0),
            new Text(
              'Please see the system log for more details.',
              style: new TextStyle(
                color: Colors.grey[600],
                fontSize: 16.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
