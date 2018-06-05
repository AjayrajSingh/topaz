// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.widgets/modular.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:sledge/sledge.dart';

/// Handles the lifecycle of the Todo module.
class TodoModuleModel extends ModuleModel {
  // ignore: unused_field
  Sledge _sledge;

  @override
  void onReady(final ModuleContext moduleContext, final Link link) {
    _sledge = new Sledge(moduleContext, new SledgePageId('my page'));
    super.onReady(moduleContext, link);
  }
}
