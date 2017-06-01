// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// The screen to video player.
class VideoScreen extends StatelessWidget {
  /// The screen for video player
  VideoScreen({
    Key key,
  })
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(
          'Video Player',
        ),
        backgroundColor: Colors.white,
      ),
      body: new Center(
        child: new Text('Video Player'),
      ),
    );
  }
}
