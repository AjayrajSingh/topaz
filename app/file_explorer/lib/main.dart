// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import 'folder_widget.dart';

Future<Null> main() async {
  runApp(
    new MaterialApp(
      home: new SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const BouncingScrollPhysics(),
        child: const FolderWidget(path: '/'),
      ),
    ),
  );
}
