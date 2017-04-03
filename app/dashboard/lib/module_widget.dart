// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:apps.modular.services.module/module.fidl.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.fidl.dart/bindings.dart';

/// A wrapper widget intended to be the root of the application that is
/// a [Module].  Its main purpose is to hold the [applicationContext] and
/// [Module] instances so they aren't garbage collected.
/// For convienence, [advertise] does the advertising of the app as a
/// [Module] to the rest of the system via the [applicationContext].
class ModuleWidget extends StatelessWidget {
  /// The [ApplicationContext] to [advertise] its [Module] services to.
  final ApplicationContext applicationContext;

  /// The [Module] to [advertise].
  final Module module;

  /// The rest of the application.
  final Widget child;

  final ModuleBinding _binding = new ModuleBinding();

  /// Constructor.
  ModuleWidget({this.applicationContext, this.module, this.child});

  @override
  Widget build(BuildContext context) => child;

  /// Advertises [module] as a [Module] to the rest of the system via the
  /// [applicationContext].
  void advertise() => applicationContext.outgoingServices.addServiceForName(
        (InterfaceRequest<Module> request) => _binding.bind(module, request),
        Module.serviceName,
      );
}
