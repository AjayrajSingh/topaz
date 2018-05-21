import 'package:flutter/widgets.dart';
import 'package:mondrian/positioned_surface.dart';
import 'package:test/test.dart';

/// Utility function to assert properties of a [PositionedSurface].
void assertSurfaceProperties(PositionedSurface surface,
    {double height, double width, Offset topLeft, Offset bottomRight}) {
  expect(surface.surface, isNotNull);
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
