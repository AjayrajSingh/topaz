// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter/material.dart';

/// A simple utility function to test equality (==) for all elements of a list.
bool listEq<T>(List<T> l1, List<T> l2) {
  if (l1 == l2) {
    return true;
  }
  if (l1 == null || l2 == null) {
    return false;
  }
  int length = l1.length;
  if (length != l2.length) {
    return false;
  }
  for (int i = 0; i < length; i++) {
    if (l1[i] != l2[i]) {
      return false;
    }
  }
  return true;
}

// We want to use some reasonable value for width, in case this widget gets
// used by itself instead of inside Editor. TODO: is there a more principled
// way to set this?
const double _nominalWidth = 200.0;

/// A widget that draws one line of text, with cursor and styles.
class TextLine extends LeafRenderObjectWidget {
  /// Creates a widget for displaying one line of text, with optional
  /// cursor decoration (when it's done).
  const TextLine(this.text, this.cursor, this.styles, this.height, {Key key})
      : super(key: key);

  /// The text displayed in the widget.
  final TextSpan text;

  /// List of cursor positions (in utf-16 offsets)
  final List<int> cursor;

  /// List of styles (in decoded triple format)
  final List<int> styles;

  /// The height of a line (currently fixed, all lines have the same height)
  final double height;

  @override
  _RenderTextLine createRenderObject(BuildContext context) {
    return _RenderTextLine(text, cursor, styles, height);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderTextLine renderObject) {
    renderObject
      ..text = text
      ..cursor = cursor
      ..styles = styles;
  }
}

class _RenderTextLine extends RenderBox {
  _RenderTextLine(
    TextSpan text,
    List<int> cursor,
    List<int> styles,
    double height,
  )   : _textPainter =
            TextPainter(text: text, textDirection: TextDirection.ltr),
        _cursor = cursor,
        _styles = styles,
        _height = height;

  TextPainter _textPainter;

  List<int> _cursor;
  // Rectangles for drawing the cursors, relative to the origin of the widget
  List<Rect> _cursorRects;
  bool _needRecomputeCursors = true;

  List<int> _styles;
  // Rectangles for drawing the selection highlight
  List<Rect> _selectionRects;
  bool _needRecomputeSelection = true;

  double _height;

  bool _needsLayout = true;

  /// The text displayed in the render object.
  set text(TextSpan value) {
    if (value == _textPainter.text) {
      return;
    }
    _textPainter.text = value;
    _needsLayout = true;
    _needRecomputeCursors = true;
    _needRecomputeSelection = true;
    markNeedsPaint();
  }

  /// List of cursor positions (in utf-16 offsets)
  set cursor(List<int> value) {
    if (listEq(value, _cursor)) {
      return;
    }
    _cursor = value;
    _needRecomputeCursors = true;
    markNeedsPaint();
  }

  /// List of styles; see LineCache for a description of the format
  set styles(List<int> value) {
    if (listEq(value, _styles)) {
      return;
    }
    _styles = value;
    _needRecomputeSelection = true;
    markNeedsPaint();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return 0.0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    return _nominalWidth;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return _height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return _height;
  }

  void _layoutIfNeeded() {
    if (_needsLayout) {
      _textPainter.layout();
      _needsLayout = false;
    }
    if (_needRecomputeCursors) {
      _cursorRects = <Rect>[];
      // TODO: if we stop building TextLine objects for cache misses, can't be null
      if (_cursor != null) {
        for (int ix in _cursor) {
          Rect caretPrototype = Rect.fromLTWH(0.0, 0.0, 1.0, _height);
          TextPosition position = TextPosition(offset: ix);
          Offset caretOffset =
              _textPainter.getOffsetForCaret(position, caretPrototype);
          _cursorRects.add(caretPrototype.shift(caretOffset));
        }
      }
      _needRecomputeCursors = false;
    }
    if (_needRecomputeSelection) {
      _selectionRects = <Rect>[];
      // TODO: if we stop building TextLine objects for cache misses, can't be null
      if (_styles != null) {
        for (int i = 0; i < _styles.length; i += 3) {
          int start = _styles[i];
          int end = _styles[i + 1];
          int styleId = _styles[i + 2];
          if (styleId == 0) {
            TextSelection selection =
                TextSelection(baseOffset: start, extentOffset: end);
            for (TextBox box in _textPainter.getBoxesForSelection(selection)) {
              _selectionRects.add(box.toRect());
            }
          }
        }
      }
      _needRecomputeSelection = false;
    }
  }

  @override
  void performLayout() {
    size = constraints.constrain(Size(_nominalWidth, _height));
    // TODO: necessary?
    _textPainter.layout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    //print('painting, offset = $offset');
    Paint paint = Paint();

    _layoutIfNeeded();
    Color cursorColor = Color(0xFF000040);
    Color selectionColor = Color(0xFFB2D8FC);
    for (Rect selectionRect in _selectionRects) {
      paint.color = selectionColor;
      context.canvas.drawRect(selectionRect.shift(offset), paint);
    }
    _textPainter.paint(context.canvas, offset);
    for (Rect cursorRect in _cursorRects) {
      paint.color = cursorColor;
      context.canvas.drawRect(cursorRect.shift(offset), paint);
    }
  }
}
