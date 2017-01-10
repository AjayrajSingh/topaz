// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xi_widgets/widgets.dart';

import 'src/xi_flutter_client.dart';

Future<Null> main() async {
  XiFlutterClient xi = new XiFlutterClient();
  runApp(new XiApp(xi: xi));
}
