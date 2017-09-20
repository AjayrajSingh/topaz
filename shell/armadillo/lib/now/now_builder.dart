// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';

import '../size_model.dart';
import 'now.dart';
import 'now_minimization_model.dart';
import 'quick_settings.dart';

/// Builds now.
class NowBuilder {
  /// How far Now should raise when quick settings is activated inline.
  static final double kQuickSettingsHeightBump = 120.0;

  /// The simulation for the minimization to a bar.
  final NowMinimizationModel _nowMinimizationModel = new NowMinimizationModel();

  final GlobalKey<QuickSettingsOverlayState> _quickSettingsOverlayKey =
      new GlobalKey<QuickSettingsOverlayState>();

  VoidCallback _onLogoutSelected;
  VoidCallback _onClearLedgerSelected;
  VoidCallback _onUserContextTapped;
  ValueChanged<bool> _onQuickSettingsOverlayChanged;

  /// Called when user requests to log out.
  set onLogoutSelected(VoidCallback onLogoutSelected) {
    _onLogoutSelected = onLogoutSelected;
  }

  /// Called when user requests to log out and clear user data.
  set onClearLedgerSelected(VoidCallback onClearLedgerSelected) {
    _onClearLedgerSelected = onClearLedgerSelected;
  }

  /// Called when the user taps the user context.
  set onUserContextTapped(VoidCallback onUserContextTapped) {
    _onUserContextTapped = onUserContextTapped;
  }

  /// Called when the quick settings overlay is shown/hidden.
  set onQuickSettingsOverlayChanged(
      ValueChanged<bool> onQuickSettingsOverlayChanged) {
    _onQuickSettingsOverlayChanged = onQuickSettingsOverlayChanged;
  }

  /// Called when now is minimized.
  set onMinimize(VoidCallback onMinimize) {
    _nowMinimizationModel.onMinimize = onMinimize;
  }

  /// Called when now is maximized.
  set onMaximize(VoidCallback onMaximize) {
    _nowMinimizationModel.onMaximize = onMaximize;
  }

  /// Builds now.
  Widget build(
    BuildContext context, {
    VoidCallback onMinimizedTap,
    VoidCallback onQuickSettingsMaximized,
    GestureDragUpdateCallback onBarVerticalDragUpdate,
    GestureDragEndCallback onBarVerticalDragEnd,
    VoidCallback onMinimizedContextTapped,
    ValueNotifier<double> recentsScrollOffset,
  }) =>
      new ScopedModelDescendant<SizeModel>(
        builder: (_, Widget child, SizeModel sizeModel) =>
            new ScopedModelDescendant<IdleModel>(
              builder: (_, Widget child, IdleModel idleModel) => new Transform(
                    transform: new Matrix4.translationValues(
                      lerpDouble(
                        0.0,
                        sizeModel.screenSize.width * 1.2,
                        idleModel.value,
                      ),
                      0.0,
                      0.0,
                    ),
                    child: new Offstage(
                      offstage: idleModel.value == 1.0,
                      child: child,
                    ),
                  ),
              child: child,
            ),
        child: new ScopedModel<NowMinimizationModel>(
          model: _nowMinimizationModel,
          child: new Stack(
            children: <Widget>[
              new RepaintBoundary(
                child: new Now(
                  quickSettingsHeightBump: kQuickSettingsHeightBump,
                  onMinimizedTap: onMinimizedTap,
                  onMinimizedLongPress: () =>
                      _quickSettingsOverlayKey.currentState.show(),
                  onQuickSettingsMaximized: onQuickSettingsMaximized,
                  onBarVerticalDragUpdate: onBarVerticalDragUpdate,
                  onBarVerticalDragEnd: onBarVerticalDragEnd,
                  onLogoutSelected: _onLogoutSelected,
                  onClearLedgerSelected: _onClearLedgerSelected,
                  onUserContextTapped: _onUserContextTapped,
                  onMinimizedContextTapped: onMinimizedContextTapped,
                  recentsScrollOffset: recentsScrollOffset,
                ),
              ),
              // Quick Settings Overlay.
              new QuickSettingsOverlay(
                key: _quickSettingsOverlayKey,
                onProgressChanged: (double progress) {
                  if (progress == 0.0) {
                    _onQuickSettingsOverlayChanged?.call(false);
                  } else {
                    _onQuickSettingsOverlayChanged?.call(true);
                  }
                },
                onLogoutSelected: _onLogoutSelected,
                onClearLedgerSelected: _onClearLedgerSelected,
              ),
            ],
          ),
        ),
      );

  /// Call when now should minimize.
  void minimize() {
    _nowMinimizationModel.minimize();
  }

  /// Call when now should maximize.
  void maximize() {
    _nowMinimizationModel.maximize();
  }
}
