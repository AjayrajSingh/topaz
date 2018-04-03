// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:mockito/mockito.dart';
import 'package:mondrian/layout_model.dart';
import 'package:mondrian/model.dart';
import 'package:mondrian/pattern_layout.dart' as pattern_layout;
import 'package:mondrian/positioned_surface.dart';
import 'package:mondrian/tree.dart';
import 'package:test/test.dart';

const double maxHeight = 100.0;
const double maxWidth = 100.0;

class MockTree extends Mock implements Tree<String> {}

class MockSurface extends Mock implements Surface {}

void main() {
  BoxConstraints constraints =
      const BoxConstraints(maxHeight: maxHeight, maxWidth: maxWidth);
  Surface firstSurface = new MockSurface();
  LayoutModel layoutModel = new LayoutModel();

  void assertSurfaceProperties(PositionedSurface surface,
      {double height, double width, Offset topLeft, Offset bottomRight}) {
    Rect position = surface.position;
    if (height != null) {
      expect(position.height, height);
    }
    if (width != null) {
      expect(position.width, width);
    }
    if (topLeft != null) {
      expect(position.topLeft, topLeft);
    }
    if (bottomRight != null) {
      expect(position.bottomRight, bottomRight);
    }
  }

  test('Ticker pattern with 2 surfaces', () {
    Tree<String> tree = new MockTree();
    when(tree.parent).thenReturn(firstSurface);
    Surface patternSurface = new MockSurface();
    when(patternSurface.parent).thenReturn(firstSurface);
    when(patternSurface.compositionPattern).thenReturn('ticker');
    List<Surface> surfaces = [
      firstSurface,
      patternSurface,
    ];
    List<PositionedSurface> positionedSurfaces = pattern_layout.layoutSurfaces(
        null /* BuildContext */, constraints, surfaces, layoutModel);
    expect(positionedSurfaces.length, 2);

    assertSurfaceProperties(positionedSurfaces[0],
        height: maxHeight * 0.85,
        width: maxWidth,
        topLeft: const Offset(0.0, 0.0));

    assertSurfaceProperties(positionedSurfaces[1],
        height: maxHeight * 0.15,
        width: maxWidth,
        topLeft: const Offset(0.0, maxHeight * 0.85));
  });

  test('Multiple tickers', () {
    Surface tickerSurface = new MockSurface();
    when(tickerSurface.compositionPattern).thenReturn('ticker');
    Surface tickerSurface2 = new MockSurface();
    when(tickerSurface2.compositionPattern).thenReturn('ticker');
    Surface tickerSurface3 = new MockSurface();
    when(tickerSurface3.compositionPattern).thenReturn('ticker');
    List<Surface> surfaces = [
      firstSurface,
      tickerSurface,
      tickerSurface2,
      tickerSurface3,
    ];
    List<PositionedSurface> positionedSurfaces = pattern_layout.layoutSurfaces(
        null /* BuildContext */, constraints, surfaces, layoutModel);
    expect(positionedSurfaces.length, 2);

    assertSurfaceProperties(positionedSurfaces[0],
        height: maxHeight * 0.85,
        width: maxWidth,
        topLeft: const Offset(0.0, 0.0));

    assertSurfaceProperties(positionedSurfaces[1],
        height: maxHeight * 0.15,
        width: maxWidth,
        topLeft: const Offset(0.0, maxHeight * 0.85));
    expect(positionedSurfaces[1].surface, tickerSurface3);
  });

  test('Comments-right pattern with 2 surfaces', () {
    Surface patternSurface = new MockSurface();
    when(patternSurface.parent).thenReturn(firstSurface);
    when(patternSurface.compositionPattern).thenReturn('comments-right');
    List<Surface> surfaces = [
      firstSurface,
      patternSurface,
    ];
    List<PositionedSurface> positionedSurfaces = pattern_layout.layoutSurfaces(
        null /* BuildContext */, constraints, surfaces, layoutModel);
    expect(positionedSurfaces.length, 2);

    assertSurfaceProperties(positionedSurfaces[0],
        height: maxHeight,
        width: maxWidth * 0.7,
        topLeft: const Offset(0.0, 0.0));

    assertSurfaceProperties(positionedSurfaces[1],
        height: maxHeight,
        width: maxWidth * 0.3,
        topLeft: const Offset(maxWidth * 0.7, 0.0));
  });

  test('Multiple comments-right', () {
    Surface commentsSurface = new MockSurface();
    when(commentsSurface.compositionPattern).thenReturn('comments-right');
    Surface commentsSurface2 = new MockSurface();
    when(commentsSurface2.compositionPattern).thenReturn('comments-right');
    Surface commentsSurface3 = new MockSurface();
    when(commentsSurface3.compositionPattern).thenReturn('comments-right');
    List<Surface> surfaces = [
      firstSurface,
      commentsSurface,
      commentsSurface2,
      commentsSurface3,
    ];
    List<PositionedSurface> positionedSurfaces = pattern_layout.layoutSurfaces(
        null /* BuildContext */, constraints, surfaces, layoutModel);
    expect(positionedSurfaces.length, 2);

    assertSurfaceProperties(positionedSurfaces[0],
        height: maxHeight,
        width: maxWidth * 0.7,
        topLeft: const Offset(0.0, 0.0));

    assertSurfaceProperties(positionedSurfaces[1],
        height: maxHeight,
        width: maxWidth * 0.3,
        topLeft: const Offset(maxWidth * 0.7, 0.0));
    expect(positionedSurfaces[1].surface, commentsSurface3);
  });

  test('Undefined pattern', () {
    Surface patternSurface = new MockSurface();
    when(patternSurface.parent).thenReturn(firstSurface);
    when(patternSurface.compositionPattern).thenReturn('undefined');
    List<Surface> surfaces = [
      firstSurface,
      patternSurface,
    ];
    List<PositionedSurface> positionedSurfaces = pattern_layout.layoutSurfaces(
        null /* BuildContext */, constraints, surfaces, layoutModel);
    expect(positionedSurfaces.length, 1);

    assertSurfaceProperties(positionedSurfaces.first,
        height: maxHeight, width: maxWidth, topLeft: const Offset(0.0, 0.0));
  });

  test('Comments and ticker', () {
    Surface commentsSurface = new MockSurface();
    when(commentsSurface.compositionPattern).thenReturn('comments-right');
    Surface tickerSurface = new MockSurface();
    when(tickerSurface.compositionPattern).thenReturn('ticker');
    List<Surface> surfaces = [
      firstSurface,
      commentsSurface,
      tickerSurface,
    ];
    List<PositionedSurface> positionedSurfaces = pattern_layout.layoutSurfaces(
        null /* BuildContext */, constraints, surfaces, layoutModel);
    expect(positionedSurfaces.length, 3);

    assertSurfaceProperties(positionedSurfaces[0],
        height: maxHeight * 0.85,
        width: maxWidth * 0.7,
        topLeft: const Offset(0.0, 0.0));

    assertSurfaceProperties(positionedSurfaces[1],
        height: maxHeight,
        width: maxWidth * 0.3,
        topLeft: const Offset(maxWidth * 0.7, 0.0));

    assertSurfaceProperties(positionedSurfaces[2],
        height: maxHeight * 0.15,
        width: maxWidth * 0.7,
        topLeft: const Offset(0.0, maxHeight * 0.85));
  });

  test('Ticker and comments', () {
    Surface commentsSurface = new MockSurface();
    when(commentsSurface.compositionPattern).thenReturn('comments-right');
    Surface tickerSurface = new MockSurface();
    when(tickerSurface.compositionPattern).thenReturn('ticker');
    List<Surface> surfaces = [
      firstSurface,
      tickerSurface,
      commentsSurface,
    ];
    List<PositionedSurface> positionedSurfaces = pattern_layout.layoutSurfaces(
        null /* BuildContext */, constraints, surfaces, layoutModel);
    expect(positionedSurfaces.length, 3);

    assertSurfaceProperties(positionedSurfaces[0],
        height: maxHeight * 0.85,
        width: maxWidth * 0.7,
        topLeft: const Offset(0.0, 0.0));

    assertSurfaceProperties(positionedSurfaces[1],
        height: maxHeight,
        width: maxWidth * 0.3,
        topLeft: const Offset(maxWidth * 0.7, 0.0));

    assertSurfaceProperties(positionedSurfaces[2],
        height: maxHeight * 0.15,
        width: maxWidth * 0.7,
        topLeft: const Offset(0.0, maxHeight * 0.85));
  });

  test('Multiple ticker and comments', () {
    Surface commentsSurface = new MockSurface();
    when(commentsSurface.compositionPattern).thenReturn('comments-right');
    Surface commentsSurface2 = new MockSurface();
    when(commentsSurface2.compositionPattern).thenReturn('comments-right');
    Surface tickerSurface = new MockSurface();
    when(tickerSurface.compositionPattern).thenReturn('ticker');
    Surface tickerSurface2 = new MockSurface();
    when(tickerSurface2.compositionPattern).thenReturn('ticker');
    List<Surface> surfaces = [
      firstSurface,
      tickerSurface,
      commentsSurface,
      tickerSurface2,
      commentsSurface2,
    ];
    List<PositionedSurface> positionedSurfaces = pattern_layout.layoutSurfaces(
        null /* BuildContext */, constraints, surfaces, layoutModel);
    expect(positionedSurfaces.length, 3);

    assertSurfaceProperties(positionedSurfaces[0],
        height: maxHeight * 0.85,
        width: maxWidth * 0.7,
        topLeft: const Offset(0.0, 0.0));

    assertSurfaceProperties(positionedSurfaces[1],
        height: maxHeight,
        width: maxWidth * 0.3,
        topLeft: const Offset(maxWidth * 0.7, 0.0));
    expect(positionedSurfaces[1].surface, commentsSurface2);

    assertSurfaceProperties(positionedSurfaces[2],
        height: maxHeight * 0.15,
        width: maxWidth * 0.7,
        topLeft: const Offset(0.0, maxHeight * 0.85));
    expect(positionedSurfaces[2].surface, tickerSurface2);
  });
}
