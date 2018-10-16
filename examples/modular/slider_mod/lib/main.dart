// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia_modular/module.dart';

import 'handlers/root_intent_handler.dart';

void main() {
  Module().registerIntentHandler(RootIntentHandler());
}
