// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia/fuchsia.dart' as fuchsia;
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.fidl._service_provider/service_provider.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.lifecycle.fidl/lifecycle.fidl.dart';
import 'package:lib.module.fidl/module.fidl.dart';
import 'package:lib.module.fidl/module_context.fidl.dart';
import 'package:lib.story.dart/story.dart';
import 'package:lib.story.fidl/link.fidl.dart';
import 'package:lib.user.fidl/device_map.fidl.dart';

/// Called when [Module.initialize] occurs.
typedef void OnModuleReady(
  ModuleContext moduleContext,
  Link link,
);

/// Called at the beginning of [Lifecycle.terminate].
typedef void OnModuleStopping();

/// Called at the conclusion of [Lifecycle.terminate].
typedef void OnModuleStop();

/// Called when the device map entry for the current device changes.
typedef void OnDeviceMapChange(DeviceMapEntry deviceMapEntry);

/// Implements a Module for receiving the services a [Module] needs to
/// operate.  When [initialize] is called, the services it receives are routed
/// by this class to the various classes which need them.
class ModuleImpl implements Module, Lifecycle {
  final ModuleContextProxy _moduleContextProxy = new ModuleContextProxy();
  final LinkProxy _linkProxy = new LinkProxy();
  final ServiceProviderBinding _outgoingServiceProviderBinding =
      new ServiceProviderBinding();
  final DeviceMapProxy _deviceMapProxy = new DeviceMapProxy();
  final DeviceMapWatcherBinding _deviceMapWatcherBinding =
      new DeviceMapWatcherBinding();

  LinkWatcherBinding _linkWatcherBinding;
  LinkWatcherImpl _linkWatcherImpl;

  /// The [ServiceProvider] to provide when outgoing services are requested.
  final ServiceProvider outgoingServiceProvider;

  /// The application context to use to get various system services.
  final ApplicationContext applicationContext;

  /// Called when [Module] is initialied with its services.
  final OnModuleReady onReady;

  /// Called at the beginning of [Lifecycle.terminate].
  final OnModuleStopping onStopping;

  /// Called at the conclusion of [Lifecycle.terminate].
  final OnModuleStop onStop;

  /// Called when [LinkWatcher.notify] is called.
  final LinkWatcherNotifyCallback onNotify;

  /// Called when the device map entry for the current device changes.
  final OnDeviceMapChange onDeviceMapChange;

  /// Indicates whether the [LinkWatcher] should watch for all changes including
  /// the changes made by this [Module]. If `true`, it calls [Link.watchAll] to
  /// register the [LinkWatcher], and [Link.watch] otherwise. Only takes effect
  /// when the [onNotify] callback is also provided. Defaults to `false`.
  final bool watchAll;

  /// Constuctor.
  ModuleImpl({
    this.applicationContext,
    this.outgoingServiceProvider,
    this.onReady,
    this.onStopping,
    this.onStop,
    this.onNotify,
    this.onDeviceMapChange,
    bool watchAll,
  })
      : watchAll = watchAll ?? false;

  @override
  void initialize(
    InterfaceHandle<ModuleContext> moduleContext,
    InterfaceRequest<ServiceProvider> outgoingServices,
  ) {
    if (onReady != null) {
      _moduleContextProxy.ctrl.bind(moduleContext);
      _moduleContextProxy.getLink(null, _linkProxy.ctrl.request());

      onReady(_moduleContextProxy, _linkProxy);
    }

    if (outgoingServices != null && outgoingServiceProvider != null) {
      _outgoingServiceProviderBinding.bind(
        outgoingServiceProvider,
        outgoingServices,
      );
    }

    if (onNotify != null) {
      _linkWatcherImpl = new LinkWatcherImpl(onNotify: onNotify);
      _linkWatcherBinding = new LinkWatcherBinding();

      if (watchAll) {
        _linkProxy.watchAll(_linkWatcherBinding.wrap(_linkWatcherImpl));
      } else {
        _linkProxy.watch(_linkWatcherBinding.wrap(_linkWatcherImpl));
      }
    }

    if (onDeviceMapChange != null) {
      connectToService(
        applicationContext.environmentServices,
        _deviceMapProxy.ctrl,
      );
      _deviceMapProxy.watchDeviceMap(
        _deviceMapWatcherBinding.wrap(
          new _DeviceMapWatcherImpl(onDeviceMapChange),
        ),
      );
    }
  }

  @override
  void terminate() {
    onStopping?.call();
    _linkWatcherBinding?.close();
    _moduleContextProxy.ctrl.close();
    _linkProxy.ctrl.close();
    _outgoingServiceProviderBinding.close();
    _deviceMapProxy.ctrl.close();
    _deviceMapWatcherBinding.close();
    onStop?.call();
    fuchsia.exit(0);
  }
}

class _DeviceMapWatcherImpl extends DeviceMapWatcher {
  OnDeviceMapChange _onDeviceMapChange;

  _DeviceMapWatcherImpl(this._onDeviceMapChange);

  @override
  void onDeviceMapChange(DeviceMapEntry entry) {
    _onDeviceMapChange?.call(entry);
  }
}
