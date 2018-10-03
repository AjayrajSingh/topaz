// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'colors.dart';

// ignore: avoid_classes_with_only_static_members
/// Fonts
class Fonts {
  /// h1 maximum font size
  static const double h1MaxFontSize = 40.0;

  /// h1 medium font size
  static const double h1MidFontSize = 32.0;

  /// h1 minimum font size
  static const double h1MinFontSize = 28.0;

  /// h2 font size
  static const double h2FontSize = 20.0;

  /// h2 font leading
  static const double h2FontLeading = 24.0;

  /// s1 font size
  static const double s1FontSize = 16.0;

  /// s1 font leading
  static const double s1FontLeading = 24.0;

  /// s2 font size
  static const double s2FontSize = 16.0;

  /// s2 font leading
  static const double s2FontLeading = 24.0;

  /// body font size
  static const double bodyFontSize = 16.0;

  /// body font leading
  static const double bodyFontLeading = 24.0;

  /// action font size
  static const double actionFontSize = 16.0;

  /// caption font size
  static const double captionFontSize = 12.0;

  /// caption font leading
  static const double captionFontLeading = 16.0;

  static const String _mainFontFamily = 'GoogleSans';
  static const String _secondaryFontFamily = 'Roboto';

  /// h1 text style
  static const TextStyle h1 = TextStyle(
    fontFamily: _mainFontFamily,
    color: grey900,
    fontSize: h1MaxFontSize,
  );

  /// h1 variations
  static TextStyle h1Dark = getDarkVariation(h1);
  static TextStyle h1Min = h1.copyWith(fontSize: h1MinFontSize);
  static TextStyle h1DarkMin = getDarkVariation(h1Min);

  /// h2 text style
  static const TextStyle h2 = TextStyle(
    fontFamily: _mainFontFamily,
    color: grey900,
    fontWeight: FontWeight.w900,
    fontSize: h2FontSize,
    height: h2FontLeading / h2FontSize,
  );

  /// h2 variations

  static TextStyle h2Dark = getDarkVariation(h2);

  /// s1 text style
  static const TextStyle s1 = TextStyle(
    fontFamily: _mainFontFamily,
    color: grey900,
    fontWeight: FontWeight.w900,
    fontSize: s1FontSize,
    height: s1FontLeading / s1FontSize,
  );

  /// s1 variations
  static TextStyle s1Dark = getDarkVariation(s1);

  /// s2 text style
  static const TextStyle s2 = TextStyle(
    fontFamily: _secondaryFontFamily,
    color: grey600,
    fontSize: s2FontSize,
    height: s2FontLeading / s2FontSize,
  );

  /// s2 variations
  static TextStyle s2Dark = getDarkVariation(s2);

  /// body text style
  static const TextStyle body = TextStyle(
    fontFamily: _secondaryFontFamily,
    color: grey900,
    fontSize: bodyFontSize,
    height: bodyFontLeading / bodyFontSize,
  );

  /// action text style
  static const TextStyle action = TextStyle(
    fontFamily: _secondaryFontFamily,
    color: grey900,
    fontWeight: FontWeight.w600,
    fontSize: actionFontSize,
  );

  /// caption text style
  static const TextStyle caption = TextStyle(
    fontFamily: _secondaryFontFamily,
    color: grey500,
    fontSize: captionFontSize,
    height: captionFontLeading / captionFontSize,
  );

  /// caption variations
  static TextStyle captionDark = getDarkVariation(caption);

  /// variation functions
  static TextStyle getDarkVariation(TextStyle style) =>
      style.copyWith(color: grey50);
}
