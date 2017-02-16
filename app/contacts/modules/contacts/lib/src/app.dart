// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'screens.dart';
import 'widgets.dart';

/// The root application.
class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Contacts',
      theme: kContactTheme,
      home: new Material(
        child: new ContactListScreen(),
      ),
    );
  }
}
