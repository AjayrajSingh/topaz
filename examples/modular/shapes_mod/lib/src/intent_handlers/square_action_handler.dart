// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:fuchsia_modular/module.dart';

class SquareActionHandler {
  void handleIntent(Intent intent) {
    runApp(
      MaterialApp(
        home: Scaffold(
            body: Center(
          child: _makeSquare(),
        )),
      ),
    );
  }

  Widget _makeSquare() => Container(
        decoration: BoxDecoration(
          color: Colors.pink,
          shape: BoxShape.rectangle,
          border: Border.all(
            color: Colors.white,
            width: 2.5,
          ),
        ),
      );
}
