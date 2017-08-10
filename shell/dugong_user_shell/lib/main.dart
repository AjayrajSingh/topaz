// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

void main() {
  runApp(
    new Stack(
      fit: StackFit.expand,
      children: <Widget>[
        new Image.asset(
          'packages/dugong_user_shell/res/dugong_bg.jpg',
          fit: BoxFit.cover,
        ),
        new PhysicalModel(
          elevation: 20.0,
          color: Colors.transparent,
          child: new Center(
            child: new Image.asset(
              'packages/dugong_user_shell/res/dugong.png',
            ),
          ),
        ),
      ],
    ),
  );
}
