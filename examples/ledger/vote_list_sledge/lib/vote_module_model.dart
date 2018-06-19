// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.widgets/modular.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';

import 'widgets/vote_list_widget.dart';

/// Handles the lifecycle of the Vote module.
class VoteModuleModel extends ModuleModel {
  @override
  void onReady(final ModuleContext moduleContext, final Link link) {
    VoteListWidgetState.moduleContext = moduleContext;
    super.onReady(moduleContext, link);
  }
}
