// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

/// Displays a set of windows.
class WindowPlaygroundWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) => new Center(
        child: new Container(
          padding: const EdgeInsets.all(12.0),
          decoration: const BoxDecoration(
            color: const Color(0xccbcbcbc),
          ),
          child: new Text("I display windows"),
        ),
      );
}
