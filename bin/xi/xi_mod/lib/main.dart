// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:fuchsia/fuchsia.dart';
import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_ledger/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:xi_widgets/widgets.dart';
import 'package:xi_fuchsia_client/client.dart';
import 'package:xi_client/client.dart';

/// ignore_for_file: avoid_annotating_with_dynamic

/// If `true`, draws the editor with a watermarked background.
const bool kDrawDebugBackground = false;

/// An implementation of the [Lifecycle] interface, which controls the lifetime
/// of the module. Also manages the ModuleContext connection.
class ModuleImpl implements Lifecycle {
  /// Constructor.
  ModuleImpl(this._ledgerRequest) {
    log.info('ModuleImpl::init call');
    connectToService(kContext.environmentServices, _moduleContext.ctrl);
    _moduleContext.getComponentContext(_componentContext.ctrl.request());
    _componentContext.getLedgerNew(_ledgerRequest);
  }

  final LifecycleBinding _lifecycleBinding = new LifecycleBinding();
  final ModuleContextProxy _moduleContext = new ModuleContextProxy();
  final ComponentContextProxy _componentContext = new ComponentContextProxy();
  final InterfaceRequest<Ledger> _ledgerRequest;

  /// Bind an [InterfaceRequest] for a [Lifecycle] interface to this object.
  void bindLifecycle(InterfaceRequest<Lifecycle> request) {
    _lifecycleBinding.bind(this, request);
  }

  @override
  void terminate() {
    log.info('ModuleImpl::stop call');

    // Cleaning up.
    _moduleContext.ctrl.close();
    _componentContext.ctrl.close();
    _lifecycleBinding.close();
    exit(0);
  }
}

/// Main entry point to the example parent module.
void main() {
  setupLogger(name: '[xi_mod]');
  log.info('Module main called');

  InterfacePair<Ledger> pair = new InterfacePair<Ledger>();
  final ModuleImpl module = new ModuleImpl(pair.passRequest());

  kContext.outgoingServices.addServiceForName(
    module.bindLifecycle,
    Lifecycle.$serviceName,
  );

  log.info('Starting Flutter app...');

  XiFuchsiaClient xi = new XiFuchsiaClient(pair.passHandle());
  XiCoreProxy coreProxy = new CoreProxy(xi);

  runApp(new EditorTabs(
    coreProxy: coreProxy,
    debugBackground: kDrawDebugBackground,
  ));
}
