// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:lib.widgets/model.dart';
import 'package:meta/meta.dart';

/// Signature of tab ownership change callbacks.
typedef void OwnershipChangeCallback(TabData data);

/// Representation of tab ids.
class TabId {
  @override
  String toString() => hashCode.toString();
}

/// Data associated with a tab.
class TabData {
  /// The tab's id.
  final TabId id;

  /// The tab's name.
  final String name;

  /// The tab's color.
  final Color color;

  /// Called when the owner of the tab changed.
  OwnershipChangeCallback onOwnerChanged;

  /// Constructor.
  TabData(this.name, this.color) : id = new TabId();
}

/// Signature of the callback to claim a tab owned by a window.
typedef TabData ClaimTabCallback(TabId id);

/// Representation of window ids.
class WindowId {
  @override
  String toString() => hashCode.toString();
}

/// Data associated with a window.
class WindowData extends Model {
  /// The window's id.
  final WindowId id;

  /// The tabs hosted by the window.
  final List<TabData> tabs;

  /// Called to claim a tab ownerd by another window.
  final ClaimTabCallback claimTab;

  /// Constructor.
  WindowData({this.tabs: const <TabData>[], @required this.claimTab})
      : id = new WindowId();

  /// Returns true if this window contains the given tab.
  bool has(TabId id) => tabs.any((TabData tab) => tab.id == id);

  /// Returns the data for the [id] tab, or the result of calling [orElse], or
  /// [null].
  TabData find(TabId id, {TabData orElse()}) => tabs.firstWhere(
        (TabData tab) => tab.id == id,
        orElse: orElse ?? () => null,
      );

  /// Attaches the given tab to this window, removing it from its previous
  /// parent window.
  bool claim(TabId id) {
    final TabData tab = find(id, orElse: () => claimTab(id));
    if (tab == null) {
      return false;
    }
    if (tabs.contains(tab)) {
      tabs.remove(tab);
    }
    tabs.add(tab);
    notifyListeners();
    return true;
  }

  /// Removes the given tab from this window and returns its data if applicable.
  TabData remove(TabId id) {
    final TabData result = find(id);
    if (result != null) {
      tabs.remove(result);
      notifyListeners();
    }
    return result;
  }

  /// Returns the tab adjacent to [id] in the list in the direction specified by
  /// [forward].
  TabId next({@required TabId id, @required bool forward}) {
    final int index = new List<int>.generate(tabs.length, (int x) => x)
        .firstWhere((int i) => tabs[i].id == id, orElse: () => -1);
    if (index == -1) {
      return null;
    }
    final int nextIndex = (index + (forward ? 1 : -1)) % tabs.length;
    return tabs[nextIndex].id;
  }
}

/// A collection of windows.
class WindowsData extends Model {
  /// The actual windows.
  final List<WindowData> windows = new List<WindowData>();

  /// Called by a window to claim a tab owned by another window.
  TabData _claimTab(TabId id) {
    WindowData window = windows.firstWhere(
      (WindowData window) => window.has(id),
      orElse: () => null,
    );
    if (window == null) {
      return null;
    }
    TabData result = window.remove(id);
    if (window.tabs.isEmpty) {
      windows.remove(window);
      notifyListeners();
    }
    return result;
  }

  /// Adds a new window, with an optional existing tab.
  void add({TabId id}) {
    final TabData tab = id != null ? _claimTab(id) : null;
    windows.add(new WindowData(
      tabs: tab != null
          ? <TabData>[tab]
          : <TabData>[
              new TabData('Alpha', const Color(0xff008744)),
              new TabData('Beta', const Color(0xff0057e7)),
              new TabData('Gamma', const Color(0xffd62d20)),
              new TabData('Delta', const Color(0xffffa700)),
            ],
      claimTab: _claimTab,
    ));
    notifyListeners();
  }

  /// Moves the given [window] to the front of the pack.
  void moveToFront(WindowData window) {
    if (windows.isEmpty ||
        !windows.contains(window) ||
        windows.last == window) {
      return;
    }
    windows.remove(window);
    windows.add(window);
    notifyListeners();
  }

  /// Returns the data for the [id] window, or the result of calling [orElse],
  /// or [null].
  WindowData find(WindowId id, {WindowData orElse()}) => windows.firstWhere(
        (WindowData window) => window.id == id,
        orElse: orElse ?? () => null,
      );

  /// Returns the window adjacent to [id] in the list in the direction specified
  /// by [forward].
  WindowId next({@required WindowId id, @required bool forward}) {
    final int index = new List<int>.generate(windows.length, (int x) => x)
        .firstWhere((int i) => windows[i].id == id, orElse: () => -1);
    if (index == -1) {
      return null;
    }
    final int nextIndex = (index + (forward ? 1 : -1)) % windows.length;
    return windows[nextIndex].id;
  }
}
