// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart' as fidl;
import 'package:fidl_fuchsia_ledger/fidl_async.dart' as ledger;
import 'package:fidl_fuchsia_sys/fidl_async.dart'
    show LaunchInfo, ComponentControllerProxy, LauncherProxy;
import 'package:fuchsia_services/services.dart';
import 'package:sledge/sledge.dart';
import 'package:zircon/zircon.dart';

/// References a service that provides channels to a unique Ledger instance.
class LedgerTestInstanceProvider {
  /// Default constructor.
  LedgerTestInstanceProvider(this.services, this._controller);

  /// The service providing channels to Ledger.
  Incoming services;
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

  final incoming = Incoming();
  final LaunchInfo launchInfo = LaunchInfo(
      url: server, directoryRequest: incoming.request().passChannel());
  final context = StartupContext.fromStartupInfo();
  final ComponentControllerProxy controller = ComponentControllerProxy();

  final launcher = LauncherProxy();
  context.incoming.connectToService(launcher);
  await launcher.createComponent(launchInfo, controller.ctrl.request());

  return LedgerTestInstanceProvider(incoming, controller);
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
  pageId ??= SledgePageId('');
  ledgerInstanceProvider ??= await newLedgerTestInstanceProvider();
  final pair = ChannelPair();
  ledgerInstanceProvider.services.connectToServiceByNameWithChannel(
      ledger.Ledger.$serviceName, pair.first);

  final sledge = _SledgeForTesting(
      fidl.InterfaceHandle<ledger.Ledger>(pair.second),
      pageId,
      ledgerInstanceProvider._controller);
  return sledge;
}
