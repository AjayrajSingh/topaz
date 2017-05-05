// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:keyboard/keyboard.dart';

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Theme(
      data: new ThemeData.light(),
      child: new Keyboard(),
    );
  }
}

void main() {
  runApp(new App());
}
