// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';

export 'package:lib.widgets/model.dart'
    show ScopedModel, Model, ScopedModelDescendant;

import 'suggestion_list.dart';

/// Target widths for the suggesiton section at different screen sizes.
const double _kTargetLargeSuggestionWidth = 736.0;
const double _kTargetSmallSuggestionWidth = 424.0;
const double _kSuggestionMinPadding = 40.0;

/// The height of Now when maximized.
const double _kMaximizedNowHeight = 440.0;

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
  Size _screenSize = Size.zero;
  double _suggestionListWidth;
  double _suggestionWidth;
  double _interruptionLeftMargin;

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

      // How sizing of the suggestion section works:
      // 1. Try to accommodate the large target width with mininum padding
      // 2. Try to accomodate the small target width with mininum padding
      // 3. Stretch to the full width of the screen
      bool stretchToFullWidth = false;
      if (_screenSize.width >=
          _kTargetLargeSuggestionWidth + 2 * _kSuggestionMinPadding) {
        _suggestionListWidth = _kTargetLargeSuggestionWidth;
      } else if (_screenSize.width >
          _kTargetSmallSuggestionWidth + 2 * _kSuggestionMinPadding) {
        _suggestionListWidth = _kTargetSmallSuggestionWidth;
      } else {
        _suggestionListWidth = _screenSize.width;
        stretchToFullWidth = true;
      }

      _suggestionWidth = SuggestionListState.getSuggestionWidth(
        _suggestionListWidth,
      );

      _interruptionLeftMargin = stretchToFullWidth
          ? (_suggestionListWidth - _suggestionWidth) / 2.0
          : 16.0;

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

  /// Gets the height of the maximized now.
  double get maximizedNowHeight => _kMaximizedNowHeight;

  /// The width of the suggestion list.
  double get suggestionListWidth => _suggestionListWidth;

  /// The width of a suggestion.
  double get suggestionWidth => _suggestionWidth;

  /// The distance from the left of the screen interruptions should show up.
  double get interruptionLeftMargin => _interruptionLeftMargin;
}
