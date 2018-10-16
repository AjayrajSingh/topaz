// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:fuchsia_modular/module.dart';

class CircleActionHandler {
  void handleIntent(Intent intent) {
    runApp(
      MaterialApp(
        home: Scaffold(
            body: Center(
          child: _makeCircle(),
        )),
      ),
    );
  }

  Widget _makeCircle() => Container(
        decoration: BoxDecoration(
          color: Colors.pink,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2.5,
          ),
        ),
      );
}
