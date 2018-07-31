// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// An interface for types which handle top-level commands from xi-core.
abstract class XiHandler {
  /// A notification containing an alert message to be shown the user.
  void alert(String text);

  /// A request to measure the width of strings. Each item in the list is a
  ///  dictionary where `style` is the id of the style and `strings` is an
  ///  array of strings to measure. The result is a list of lists of widths.
  List<double> measureWidths(List<Map<String, dynamic>> args);

  /// Returns the [XiViewHandler] responsible for the provided `viewId`.
  XiViewHandler getView(String viewId);
}

/// An interface for types which handle view-level commands from xi-core.
abstract class XiViewHandler {
  /// An update to the view's contents. The update protocol is documented at
  /// http://google.github.io/xi-editor/docs/frontend-protocol.html#view-update-protocol
  void update(List<Map<String, dynamic>> params);

  /// A notification that the view should change its visible scroll area.
  void scrollTo(int line, int col);
}
