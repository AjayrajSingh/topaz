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
  Surface parentSurface = new MockSurface();
  LayoutModel layoutModel = new LayoutModel();

  test('Ticker pattern with 2 surfaces', () {
    Tree<String> tree = new MockTree();
    when(tree.parent).thenReturn(parentSurface);
    Surface patternSurface = new MockSurface();
    when(patternSurface.parent).thenReturn(parentSurface);
    when(patternSurface.compositionPattern).thenReturn('ticker');
    List<Surface> surfaces = [
      parentSurface,
      patternSurface,
    ];
    List<PositionedSurface> positionedSurfaces = pattern_layout.layoutSurfaces(
        null /* BuildContext */, constraints, surfaces, layoutModel);
    expect(positionedSurfaces.length, 2);
    PositionedSurface first = positionedSurfaces.first;
    PositionedSurface second = positionedSurfaces[1];

    expect(first.position.height, maxHeight * 0.85);
    expect(first.position.width, maxWidth);
    expect(second.position.height, maxHeight * 0.15);
    expect(second.position.width, maxWidth);

    expect(first.position.topLeft, const Offset(0.0, 0.0));
    expect(second.position.topLeft, const Offset(0.0, maxHeight * 0.85));
  });

  test('Comments-right pattern with 2 surfaces', () {
    Tree<String> tree = new MockTree();
    when(tree.parent).thenReturn(parentSurface);
    Surface patternSurface = new MockSurface();
    when(patternSurface.parent).thenReturn(parentSurface);
    when(patternSurface.compositionPattern).thenReturn('comments-right');
    List<Surface> surfaces = [
      parentSurface,
      patternSurface,
    ];
    List<PositionedSurface> positionedSurfaces = pattern_layout.layoutSurfaces(
        null /* BuildContext */, constraints, surfaces, layoutModel);
    expect(positionedSurfaces.length, 2);
    PositionedSurface first = positionedSurfaces.first;
    PositionedSurface second = positionedSurfaces[1];

    expect(first.position.height, maxHeight);
    expect(first.position.width, maxWidth * 0.7);
    expect(second.position.width, maxWidth * 0.3);
    expect(second.position.height, maxHeight);

    expect(first.position.topLeft, const Offset(0.0, 0.0));
    expect(second.position.topLeft, const Offset(maxWidth * 0.7, 0.0));
  });

  test('Undefined pattern', () {
    Tree<String> tree = new MockTree();
    when(tree.parent).thenReturn(parentSurface);
    Surface patternSurface = new MockSurface();
    when(patternSurface.parent).thenReturn(parentSurface);
    when(patternSurface.compositionPattern).thenReturn('undefined');
    List<Surface> surfaces = [
      parentSurface,
      patternSurface,
    ];
    List<PositionedSurface> positionedSurfaces = pattern_layout.layoutSurfaces(
        null /* BuildContext */, constraints, surfaces, layoutModel);
    expect(positionedSurfaces.length, 1);
    PositionedSurface first = positionedSurfaces.first;

    expect(first.position.height, maxHeight);
    expect(first.position.width, maxWidth);
    expect(first.position.topLeft, const Offset(0.0, 0.0));
  });
}
