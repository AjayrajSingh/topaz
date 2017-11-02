// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../widgets.dart';

/// The screen to video player
class VideoApp extends StatelessWidget {
  /// The screen for video player
  const VideoApp({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Video Player',
      home: const Material(
        child: const Player(),
      ),
    );
  }
}
