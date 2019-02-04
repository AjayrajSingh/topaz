// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart' as fidl;
import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;
import 'package:fidl_fuchsia_sys/fidl_async.dart'
    show LaunchInfo, ComponentControllerProxy;
import 'package:lib.app.dart/app_async.dart' show Services, StartupContext;
import 'package:sledge/sledge.dart';

/// References a service that provides channels to a unique Ledger instance.
class LedgerTestInstanceProvider {
  /// Default constructor.
  LedgerTestInstanceProvider(this.services, this._controller);

  /// The service providing channels to Ledger.
  Services services;
  // Prevents the controller from being GCed, which would result in the service
  // being closed.
  // ignore: unused_field
  ComponentControllerProxy _controller;
}

/// Returns a new LedgerTestInstanceProvider that creates connections to a
/// in-memory Ledger.
Future<LedgerTestInstanceProvider> newLedgerTestInstanceProvider() async {
  String server =
      'fuchsia-pkg://fuchsia.com/ledger_test_instance_provider#meta/ledger_test_instance_provider.cmx';
  final Services services = new Services();
  final LaunchInfo launchInfo =
      new LaunchInfo(url: server, directoryRequest: services.request());
  final context = new StartupContext.fromStartupInfo();
  final ComponentControllerProxy controller = new ComponentControllerProxy();
  await context.launcher.createComponent(launchInfo, controller.ctrl.request());
  return new LedgerTestInstanceProvider(services, controller);
}

/// Sledge subclass that makes sure the ComponentControllerProxy does not get GCed.
class _SledgeForTesting extends Sledge {
  _SledgeForTesting(fidl.InterfaceHandle<ledger.Ledger> ledgerHandle,
      SledgePageId pageId, this._controller)
      : super.fromLedgerHandle(ledgerHandle, pageId);
  // Prevents the connection to Ledger from being closed.
  // ignore: unused_field
  ComponentControllerProxy _controller;
}

/// Creates a new test Sledge instance backed by an in-memory Ledger provided
/// by [ledgerInstanceProvider].
/// If no [ledgerInstanceProvider] is provided, a new provider is created.
Future<Sledge> newSledgeForTesting(
    {SledgePageId pageId,
    LedgerTestInstanceProvider ledgerInstanceProvider}) async {
  pageId ??= new SledgePageId('');
  ledgerInstanceProvider ??= await newLedgerTestInstanceProvider();
  fidl.InterfaceHandle<ledger.Ledger> ledgerHandle =
      await ledgerInstanceProvider.services
          .connectToServiceByName<ledger.Ledger>(ledger.Ledger.$serviceName);
  final sledge = new _SledgeForTesting(
      ledgerHandle, pageId, ledgerInstanceProvider._controller);
  return sledge;
}
