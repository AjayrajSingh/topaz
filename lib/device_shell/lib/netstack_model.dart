// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_net/fidl.dart' as net;
import 'package:fidl_fuchsia_netstack/fidl.dart' as ns;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.widgets/model.dart';

const String _kLoopbackInterfaceName = 'en1';

const Duration _kRepeatAnimationDuration = const Duration(milliseconds: 400);

const Duration _kRevealAnimationDuration = const Duration(milliseconds: 200);
void _updateAnimations(
  bool oldValue,
  bool newValue,
  AnimationController reveal,
  AnimationController repeat,
) {
  if (newValue) {
    reveal.forward();
  } else {
    reveal.reverse();
  }
  if (newValue && oldValue && !repeat.isAnimating) {
    repeat
      ..value = 0.0
      ..forward();
  }
}

/// Information about an interface.
class InterfaceInfo {
  /// The animation to use when revealing receiving information.
  AnimationController receivingRevealAnimation;

  /// The animation to use when repeating receiving information.
  AnimationController receivingRepeatAnimation;

  /// The animation to use when revealing sending information.
  AnimationController sendingRevealAnimation;

  /// The animation to use when repeating sending information.
  AnimationController sendingRepeatAnimation;
  ns.NetInterface _interface;
  ns.NetInterfaceStats _stats;
  bool _receiving = false;
  bool _sending = false;

  /// Constructor.
  InterfaceInfo(this._interface, this._stats, TickerProvider _vsync) {
    receivingRevealAnimation = new AnimationController(
      duration: _kRevealAnimationDuration,
      vsync: _vsync,
    );
    receivingRepeatAnimation = new AnimationController(
      duration: _kRepeatAnimationDuration,
      vsync: _vsync,
    );
    sendingRevealAnimation = new AnimationController(
      duration: _kRevealAnimationDuration,
      vsync: _vsync,
    );
    sendingRepeatAnimation = new AnimationController(
      duration: _kRepeatAnimationDuration,
      vsync: _vsync,
    );
  }

  /// Name of the interface.
  String get name => _interface.name;

  void _update(ns.NetInterface interface, ns.NetInterfaceStats stats) {
    _interface = interface;

    bool oldReceiving = _receiving;
    _receiving = _stats.rx.bytesTotal != stats.rx.bytesTotal;
    _updateAnimations(
      oldReceiving,
      _receiving,
      receivingRevealAnimation,
      receivingRepeatAnimation,
    );

    bool oldSending = _sending;
    _sending = _stats.tx.bytesTotal != stats.tx.bytesTotal;
    _updateAnimations(
      oldSending,
      _sending,
      sendingRevealAnimation,
      sendingRepeatAnimation,
    );

    _stats = stats;
  }
}

/// Provides netstack information.
class NetstackModel extends Model with TickerProviderModelMixin {
  /// The netstack containing networking information for the device.
  final ns.NetstackProxy netstack;
  final net.ConnectivityProxy connectivity = net.ConnectivityProxy();

  final ValueNotifier<bool> networkReachable = ValueNotifier<bool>(false);

  final Map<int, InterfaceInfo> _interfaces = <int, InterfaceInfo>{};

  /// Constructor.
  NetstackModel({this.netstack}) {
    connectToService(StartupContext.fromStartupInfo().environmentServices,
        connectivity.ctrl);
    networkReachable.addListener(notifyListeners);
    connectivity.onNetworkReachable = (reachable) {
      networkReachable.value = reachable;
    };
  }

  /// The current interfaces on the device.
  List<InterfaceInfo> get interfaces => _interfaces.values.toList();

  void interfacesChanged(List<ns.NetInterface> interfaces) {
    List<ns.NetInterface> filteredInterfaces = interfaces
        .where((ns.NetInterface interface) =>
            interface.name != _kLoopbackInterfaceName)
        .toList();

    List<int> ids = filteredInterfaces
        .map((ns.NetInterface interface) => interface.id)
        .toList();

    _interfaces.keys
        .where((int id) => !ids.contains(id))
        .toList()
        .forEach(_interfaces.remove);

    for (ns.NetInterface interface in filteredInterfaces) {
      netstack.getStats(
        interface.id,
        (ns.NetInterfaceStats stats) {
          if (_interfaces[interface.id] == null) {
            _interfaces[interface.id] = new InterfaceInfo(
              interface,
              stats,
              this,
            );
          } else {
            _interfaces[interface.id]._update(interface, stats);
          }
          notifyListeners();
        },
      );
    }
  }

  /// Starts listening for netstack interfaces.
  void start() {
    netstack.onInterfacesChanged = interfacesChanged;
  }

  /// Stops listening for netstack interfaces.
  void stop() {
    netstack.onInterfacesChanged = null;
  }
}
