// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// The screen to video player.
class Screen extends StatelessWidget {
  /// The screen for video player
  Screen({
    Key key,
  })
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new Expanded(
      child: new Center(
        child: new Text('screen goes here!',
            style: new TextStyle(color: Colors.grey[50])),
      ),
    );
  }
}
