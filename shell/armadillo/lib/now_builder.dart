// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'now.dart';

/// Builds now.
class NowBuilder {
  /// How far Now should raise when quick settings is activated inline.
  static final double kQuickSettingsHeightBump = 120.0;

  final GlobalKey<NowState> _nowKey = new GlobalKey<NowState>();

  /// Builds now.
  Widget build(
    BuildContext context, {
    ValueChanged<double> onQuickSettingsProgressChange,
    VoidCallback onMinimizedTap,
    VoidCallback onMinimizedLongPress,
    VoidCallback onMinimize,
    VoidCallback onMaximize,
    VoidCallback onQuickSettingsMaximized,
    VoidCallback onOverscrollThresholdRelease,
    GestureDragUpdateCallback onBarVerticalDragUpdate,
    GestureDragEndCallback onBarVerticalDragEnd,
    ScrollController scrollController,
    VoidCallback onLogoutSelected,
    VoidCallback onClearLedgerSelected,
    VoidCallback onUserContextTapped,
    VoidCallback onMinimizedContextTapped,
  }) =>
      new RepaintBoundary(
        child: new Now(
          key: _nowKey,
          quickSettingsHeightBump: kQuickSettingsHeightBump,
          onQuickSettingsProgressChange: onQuickSettingsProgressChange,
          onMinimizedTap: onMinimizedTap,
          onMinimizedLongPress: onMinimizedLongPress,
          onQuickSettingsMaximized: onQuickSettingsMaximized,
          onMinimize: onMinimize,
          onMaximize: onMaximize,
          onBarVerticalDragUpdate: onBarVerticalDragUpdate,
          onBarVerticalDragEnd: onBarVerticalDragEnd,
          onOverscrollThresholdRelease: onOverscrollThresholdRelease,
          scrollController: scrollController,
          onLogoutSelected: onLogoutSelected,
          onClearLedgerSelected: onClearLedgerSelected,
          onUserContextTapped: onUserContextTapped,
          onMinimizedContextTapped: onMinimizedContextTapped,
        ),
      );

  /// Call when the recents scroll offset changes.
  void onRecentsScrollOffsetChanged(double recentsScrollOffset) {
    _nowKey.currentState.scrollOffset = recentsScrollOffset;
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
}
