// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:apps.modular.lib.app.dart/app.dart';

void main(List<String> args) {
  print('args: $args');

  ApplicationContext context = new ApplicationContext.fromStartupInfo();
}
