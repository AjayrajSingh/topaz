// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';

export 'package:lib.widgets/model.dart'
    show ScopedModel, Model, ScopedModelDescendant;

/// The [SizeModel] tracks various global sizes that are required for rendering
/// the various parts of Armadillo.
///
/// The sizes that are tracked:
/// * ScreenSize: The size allocated to Armadillo.
/// * MinimizedNowHeight: The height of the minimized now bar which is based on
///   the total ScreenSize.
///
/// The [SizeModel] allows these values to be passed down the widget tree by
/// using a [ScopedModel] to retrieve the model.
class SizeModel extends Model {
  Size _screenSize;

  /// Wraps [ModelFinder.of] for this [Model]. See [ModelFinder.of] for more
  /// details.
  static SizeModel of(BuildContext context) =>
      new ModelFinder<SizeModel>().of(context);

  /// Gets the size of the entire space allocated to Armadillo
  Size get screenSize => _screenSize;

  /// Sets the screen size
  set screenSize(Size size) {
    if (size != _screenSize) {
      _screenSize = size;
      notifyListeners();
    }
  }

  /// Gets the size of a focused story.
  ///
  /// The story size is the screen size minus the minimized now bar height
  Size get storySize => new Size(
        _screenSize.width,
        _screenSize.height - minimizedNowHeight,
      );

  /// Gets the height of the minimized now bar which is based on the height
  /// of the screen.
  double get minimizedNowHeight => _screenSize.height >= 640.0 ? 48.0 : 32.0;
}
