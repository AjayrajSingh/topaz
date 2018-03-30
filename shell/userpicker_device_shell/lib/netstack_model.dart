// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:fuchsia.fidl.netstack/netstack.dart' as net;
import 'package:lib.widgets/model.dart';

const String _kLoopbackInterfaceName = 'en1';

/// Provides netstack information.
class NetstackModel extends Model implements net.NotificationListener {
  /// The netstack containing networking information for the device.
  final net.Netstack netstack;

  final Map<int, InterfaceInfo> _interfaces = <int, InterfaceInfo>{};

  /// Ticker provider for animations.
  final TickerProvider tickerProvider;

  net.NotificationListenerBinding _binding;

  /// Constructor.
  NetstackModel({
    this.netstack,
    this.tickerProvider,
  });

  /// Starts listening for netstack interfaces.
  void start() {
    _binding?.close();
    _binding = new net.NotificationListenerBinding();
    netstack
      ..registerListener(_binding.wrap(this))
      ..getInterfaces(onInterfacesChanged);
  }

  /// Stops listening for netstack interfaces.
  void stop() {
    _binding?.close();
  }

  @override
  void onInterfacesChanged(List<net.NetInterface> interfaces) {
    List<net.NetInterface> filteredInterfaces = interfaces
        .where((net.NetInterface interface) =>
            interface.name != _kLoopbackInterfaceName)
        .toList();

    List<int> ids = filteredInterfaces
        .map((net.NetInterface interface) => interface.id)
        .toList();

    _interfaces.keys
        .where((int id) => !ids.contains(id))
        .toList()
        .forEach(_interfaces.remove);

    for (net.NetInterface interface in filteredInterfaces) {
      netstack.getStats(
        interface.id,
        (net.NetInterfaceStats stats) {
          if (_interfaces[interface.id] == null) {
            _interfaces[interface.id] = new InterfaceInfo(
              interface,
              stats,
              tickerProvider,
            );
          } else {
            _interfaces[interface.id]._update(interface, stats);
          }
          notifyListeners();
        },
      );
    }
  }

  /// The current interfaces on the device.
  List<InterfaceInfo> get interfaces => _interfaces.values.toList();

  /// Returns true if the netstack has an ip.
  bool get hasIp =>
      interfaces.any((InterfaceInfo interfaceInfo) => interfaceInfo.hasIp);
}

const Duration _kRevealAnimationDuration = const Duration(milliseconds: 200);
const Duration _kRepeatAnimationDuration = const Duration(milliseconds: 400);

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
  net.NetInterface _interface;
  net.NetInterfaceStats _stats;
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

  /// Returns true if we have an ip.
  bool get hasIp =>
      ((_interface.addr.ipv4?.length ?? 0) == 4 &&
          _interface.addr.ipv4[0] != 0) ||
      ((_interface.addr.ipv6?.length ?? 0) == 6 &&
          _interface.addr.ipv6[0] != 0 &&
          (_interface.addr.ipv6[0] << 8 | _interface.addr.ipv6[1]) != 0xfe80);

  void _update(net.NetInterface interface, net.NetInterfaceStats stats) {
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
