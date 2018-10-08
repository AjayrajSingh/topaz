// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_driver/driver_extension.dart';
import 'main.dart' as example_main;

/// Driver entry point to the driver example app. Enables the driver extensions
/// which will make testing possible.
void main() {
  enableFlutterDriverExtension();
  example_main.main();
}
