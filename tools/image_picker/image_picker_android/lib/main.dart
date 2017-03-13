// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:config_flutter/config.dart';
import 'package:flutter/material.dart';
import 'package:widgets/image_picker.dart';

Future<Null> main() async {
  // Get the config object.
  FlutterConfig config = await FlutterConfig.read('assets/config.json');

  runApp(new MaterialApp(
    title: 'Image Picker',
    theme: new ThemeData(
      primarySwatch: Colors.blue,
    ),
    home: new Scaffold(
      body: new Container(
        margin: const EdgeInsets.only(top: 30.0),
        child: new GoogleSearchImagePicker(
            apiKey: config.get('google_search_key'),
            customSearchId: config.get('google_search_id'),
            onAdd: (List<String> images) {
              print('added:');
              print(images);
            }),
      ),
    ),
  ));
}
