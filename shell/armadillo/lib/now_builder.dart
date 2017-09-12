// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'now.dart';
import 'quick_settings.dart';

/// Builds now.
class NowBuilder {
  /// How far Now should raise when quick settings is activated inline.
  static final double kQuickSettingsHeightBump = 120.0;

  final GlobalKey<NowState> _nowKey = new GlobalKey<NowState>();
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

  /// Builds now.
  Widget build(
    BuildContext context, {
    ValueChanged<double> onQuickSettingsProgressChange,
    VoidCallback onMinimizedTap,
    VoidCallback onMinimize,
    VoidCallback onMaximize,
    VoidCallback onQuickSettingsMaximized,
    VoidCallback onOverscrollThresholdRelease,
    GestureDragUpdateCallback onBarVerticalDragUpdate,
    GestureDragEndCallback onBarVerticalDragEnd,
    VoidCallback onMinimizedContextTapped,
  }) =>
      new Stack(
        children: <Widget>[
          new RepaintBoundary(
            child: new Now(
              key: _nowKey,
              quickSettingsHeightBump: kQuickSettingsHeightBump,
              onQuickSettingsProgressChange: onQuickSettingsProgressChange,
              onMinimizedTap: onMinimizedTap,
              onMinimizedLongPress: () =>
                  _quickSettingsOverlayKey.currentState.show(),
              onQuickSettingsMaximized: onQuickSettingsMaximized,
              onMinimize: onMinimize,
              onMaximize: onMaximize,
              onBarVerticalDragUpdate: onBarVerticalDragUpdate,
              onBarVerticalDragEnd: onBarVerticalDragEnd,
              onOverscrollThresholdRelease: onOverscrollThresholdRelease,
              onLogoutSelected: _onLogoutSelected,
              onClearLedgerSelected: _onClearLedgerSelected,
              onUserContextTapped: _onUserContextTapped,
              onMinimizedContextTapped: onMinimizedContextTapped,
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
      );

  /// Call when the recents scroll offset changes.
  void onRecentsScrollOffsetChanged(double recentsScrollOffset, bool ignore) {
    _nowKey.currentState.onRecentsScrollOffsetChanged(
      recentsScrollOffset,
      ignore,
    );
  }

  /// Call when now should minimize.
  void onMinimize() {
    _nowKey.currentState.minimize();
    _nowKey.currentState.hideQuickSettings();
  }

  /// Call when now should maximize.
  void onMaximize() {
    _nowKey.currentState.maximize();
  }

  /// Call when quick settings should be hidden.
  void onHideQuickSettings() {
    _nowKey.currentState.hideQuickSettings();
  }
}
