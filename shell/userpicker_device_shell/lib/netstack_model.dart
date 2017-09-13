// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.netstack.fidl/netstack.fidl.dart';
import 'package:lib.widgets/model.dart';

const String _kLoopbackInterfaceName = 'en1';

/// Provides netstack information.
class NetstackModel extends Model {
  /// The netstack containing networking information for the device.
  final Netstack netstack;

  final Map<int, InterfaceInfo> _interfaces = <int, InterfaceInfo>{};

  /// How often to poll the netstack for interface and stats information.
  final Duration updatePeriod;

  /// Ticker provider for animations.
  final TickerProvider tickerProvider;

  /// Constructor.
  NetstackModel({
    this.netstack,
    this.updatePeriod: const Duration(seconds: 1),
    this.tickerProvider,
  }) {
    _update();
    new Timer.periodic(updatePeriod, (_) {
      _update();
    });
  }

  void _update() {
    netstack.getInterfaces((List<NetInterface> interfaces) {
      List<NetInterface> filteredInterfaces = interfaces
          .where((NetInterface interface) =>
              interface.name != _kLoopbackInterfaceName)
          .toList();

      List<int> ids = filteredInterfaces
          .map((NetInterface interface) => interface.id)
          .toList();

      _interfaces.keys
          .where((int id) => !ids.contains(id))
          .toList()
          .forEach((int id) {
        _interfaces.remove(id);
      });

      filteredInterfaces.forEach((NetInterface interface) {
        netstack.getStats(
          interface.id,
          (NetInterfaceStats stats) {
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
      });
    });
  }

  /// The current interfaces on the device.
  List<InterfaceInfo> get interfaces => _interfaces.values.toList();
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
  NetInterface _interface;
  NetInterfaceStats _stats;
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

  void _update(
    NetInterface interface,
    NetInterfaceStats stats,
  ) {
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
    repeat.value = 0.0;
    repeat.forward();
  }
}
