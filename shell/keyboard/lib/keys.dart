// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

abstract class _KeyboardKey extends StatefulWidget {
  /// Constructor.
  const _KeyboardKey({
    @required this.height,
    @required this.onTap,
    this.flex = 2,
    Key key,
  }) : super(key: key);

  /// The size of the key relative to its siblings.
  final int flex;

  /// The height of the key.
  final double height;

  /// Called when the key is pressed.
  final Function onTap;
}

/// Called when a key is pressed.
typedef OnText = void Function(String text);

/// A spacer that is inserted into the keyboard to provide empty space
/// between other keys in the keyboard.
///
/// Note: No state is required but necessary in order to subclass [_KeyboardKey].
class SpacerKey extends _KeyboardKey {
  const SpacerKey({
    GlobalKey key,
    int flex,
  }) : super(key: key, height: 0.0, flex: flex, onTap: null);

  @override
  State<StatefulWidget> createState() => _SpacerKeyState();
}

/// Holds the current state of the [SpacerKey].
class _SpacerKeyState extends State<SpacerKey> {
  @override
  Widget build(BuildContext context) =>
      Spacer(flex: widget.flex, key: widget.key);
}

/// A key that is represented by a string.  The [TextKey] is expected to have
/// a [Row] as a parent.
class TextKey extends _KeyboardKey {
  /// The text to display.
  final String text;

  /// The style of the text.
  final TextStyle style;

  /// The vertical alignment the text should have within its container.
  final double verticalAlign;

  /// The horizontal alignment the text should have within its container.
  final double horizontalAlign;

  /// Constructor.
  const TextKey(
    this.text, {
    @required double height,
    GlobalKey key,
    OnText onText,
    this.style,
    this.verticalAlign = 0.5,
    this.horizontalAlign = 0.5,
    int flex,
  }) : super(key: key, height: height, flex: flex, onTap: onText);

  @override
  TextKeyState createState() => TextKeyState();
}

/// Holds the current text and down state of the [TextKey].
class TextKeyState extends State<TextKey> {
  String _text;

  @override
  void initState() {
    super.initState();
    _text = widget.text;
  }

  @override
  void didUpdateWidget(_) {
    super.didUpdateWidget(_);
    setState(() => _text = widget.text);
  }

  @override
  Widget build(BuildContext context) => Expanded(
        flex: widget.flex,
        child: _buildMaterialWrapper(
          child: Container(
            height: widget.height,
            child: Align(
              alignment: FractionalOffset(
                widget.horizontalAlign,
                widget.verticalAlign,
              ),
              child: Text(_text, style: widget.style),
            ),
          ),
          onTap: () => widget.onTap?.call(_text),
        ),
      );

  /// Sets the text of the key.
  set text(String text) => setState(() => _text = text);
}

/// A key that is represented by an image.  The [ImageKey] is expected to have
/// a [Row] as a parent.
class ImageKey extends _KeyboardKey {
  /// The url of the image.
  final String imageUrl;

  /// The color filter to apply to the image in the key.
  final Color imageColor;

  /// Constructor.
  const ImageKey({
    @required this.imageUrl,
    @required this.imageColor,
    @required double height,
    VoidCallback onKeyPressed,
    int flex,
    Key key,
  }) : super(
          height: height,
          flex: flex,
          key: key,
          onTap: onKeyPressed,
        );

  @override
  _ImageKeyState createState() => _ImageKeyState();
}

/// Holds the current down state of the [ImageKey].
class _ImageKeyState extends State<ImageKey> {
  static const double _kPadding = 20.0 / 3.0;

  @override
  Widget build(BuildContext context) => Expanded(
        flex: widget.flex,
        child: _buildMaterialWrapper(
          child: Container(
            padding: const EdgeInsets.all(_kPadding),
            height: widget.height,
            child: Container(
              padding: EdgeInsets.all(4.0),
              child: Image(
                image: AssetImage(widget.imageUrl),
                fit: BoxFit.contain,
                color: widget.imageColor,
              ),
            ),
          ),
          onTap: widget.onTap ?? () {},
        ),
      );
}

Widget _buildMaterialWrapper({
  @required Widget child,
  @required VoidCallback onTap,
}) =>
    Material(
      child: InkWell(onTap: onTap, child: child),
      color: Colors.transparent,
    );
