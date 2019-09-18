// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:fuchsia_scenic_flutter/child_view_connection.dart';

/// Allow presenters to request removal of surfaces.
typedef RemoveSurfaceCallback = void Function(Iterable<String>);

/// Allow presenters to notify changes on focused surfaces to modular for purposes
/// of ranking in context and suggestions.
typedef FocusChangeCallback = void Function(String, bool);

/// The layout strategy manages a model of the layout that is shared with the
/// Presenter through the LayoutModel.
abstract class Layout {
  /// Called when a surface is removed
  RemoveSurfaceCallback removeSurface;

  /// Called when the focus of a surface changes.
  FocusChangeCallback changeFocus;

  /// Constructor for a layout strategy.
  Layout({
    this.removeSurface,
    this.changeFocus,
  });

  /// These fields depend on the host environment. If this is used
  /// outside of Fuchsia, change ChildViewConnection to flutter Widget.
  void addSurface({
    String surfaceId,
    String intent,
    ChildViewConnection view,
    UnmodifiableListView<String> parameters,
  });

  /// Instructs to delete a surface.
  void deleteSurface(String surfaceId);
}
