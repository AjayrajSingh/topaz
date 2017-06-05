// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../modular/module_model.dart';
import 'play_bar.dart';
import 'screen.dart';

/// The screen to video player.
class Player extends StatelessWidget {
  /// Model that stores video playback state
  final VideoModuleModel model;

  /// The screen for video player
  Player({
    Key key,
    this.model,
  })
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget screen = new Screen();
    Widget playbar = new PlayBar(
      model: model,
    );
    return new Container(
      color: Colors.black,
      child: new Column(
        children: <Widget>[
          screen,
          playbar,
        ],
      ),
    );
  }
}
