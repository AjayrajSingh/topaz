// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:keyboard/constants.dart'
    as keyboard; // Temporary solution for keyboard height.
import 'package:lib.app.dart/app.dart';
import 'package:lib.widgets/application.dart';
import 'package:lib.widgets/model.dart';
import 'package:topaz.lib.shell/models/overlay_position_model.dart';

import 'keyboard_model.dart';

const double _kKeyboardOverlayHeight = keyboard.keyboardHeight;
const double _kKeyboardCornerRadius = keyboard.cornerRadius;

/// Defines the UX of the keyboard drawer.
class KeyboardContainer extends StatelessWidget {
  const KeyboardContainer({this.model, this.elevation});

  final KeyboardModel model;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    return model == null
        ? ScopedModelDescendant<KeyboardModel>(
            builder: (_, __, keyboardModel) => _buildKeyboard(keyboardModel),
          )
        : _buildKeyboard(model);
  }

  Widget _buildKeyboard(KeyboardModel model) {
    return AnimatedBuilder(
      animation: model.overlayPositionModel,
      builder: (BuildContext context, Widget child) {
        double yShift = lerpDouble(
          _kKeyboardOverlayHeight,
          0.0,
          model.overlayPositionModel.value,
        );
        yShift += model.overlayPositionModel.overlayDragModel.offset;
        yShift = yShift.clamp(0.0, _kKeyboardOverlayHeight);
        return Offstage(
          offstage: yShift >= _kKeyboardOverlayHeight,
          child: Align(
            alignment: FractionalOffset.bottomCenter,
            child: Transform(
              transform: Matrix4.translationValues(
                0.0,
                yShift,
                0.0,
              ),
              child: child,
            ),
          ),
        );
      },
      child: SizedBox(
        height: _kKeyboardOverlayHeight,
        child: Material(
          borderRadius: const BorderRadius.vertical(
              top: const Radius.circular(_kKeyboardCornerRadius)),
          elevation: elevation ?? model.keyboardElevation,
          child: ApplicationWidget(
            url: 'latin-ime',
            focusable: false,
            launcher: StartupContext.fromStartupInfo().launcher,
          ),
        ),
      ),
    );
  }
}
