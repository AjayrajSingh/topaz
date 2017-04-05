// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.services/service_provider.fidl.dart';
import 'package:apps.modular.services.module/module_context.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:lib.widgets/model.dart';

import 'module_widget.dart';

export 'package:lib.widgets/model.dart' show ScopedModel, ScopedModelDescendant;


/// A [Model] that waits for the [ModuleWidget] it's given to to call its
/// [onReady].  This [Model] will then be available to all children of
/// [ModuleWidget].
class ModuleModel extends Model {
  ModuleContext _moduleContext;
  Link _link;
  ServiceProvider _incomingServiceProvider;

  ModuleContext get moduleContext => _moduleContext;
  Link get link => _link;
  ServiceProvider get incomingServiceProvider => _incomingServiceProvider;

  void onReady(
    ModuleContext moduleContext,
    Link link,
    ServiceProvider incomingServiceProvider,
  ) {
    _moduleContext = moduleContext;
    _link = link;
    _incomingServiceProvider = incomingServiceProvider;
    notifyListeners();
  }

  void onStop() => null;
}
