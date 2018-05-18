// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

/// The loading screen when casting fails
class Loading extends StatelessWidget {
  /// Name of remote device to cast to
  final String remoteDeviceName;

  /// Constructor for the loading screen
  const Loading({
    @required this.remoteDeviceName,
    Key key,
  })  : assert(remoteDeviceName != null),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return new Container(
      color: Colors.black,
      child: new Center(
        child: new Column(
          children: <Widget>[
            new Padding(
              padding: const EdgeInsets.only(top: 40.0, bottom: 10.0),
              child: new Container(
                height: 64.0,
                width: 64.0,
                child: new CircularProgressIndicator(
                  valueColor:
                      new AlwaysStoppedAnimation<Color>(Colors.grey[500]),
                ),
              ),
            ),
            new Text(
              remoteDeviceName.toUpperCase(),
              style: new TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
