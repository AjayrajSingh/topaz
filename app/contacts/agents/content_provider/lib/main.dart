// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.logging/logging.dart';

Future<Null> main(List<String> args) async {
  setupLogger(name: 'contacts/agent');
}
