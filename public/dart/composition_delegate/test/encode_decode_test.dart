// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:composition_delegate/composition_delegate.dart';
import 'package:test/test.dart';

void main() {
  SurfaceLayout layout = SurfaceLayout(
      x: 1.0, y: 2.0, w: 3.0, h: 1000000000000.0, surfaceId: 'first');
  Map<String, dynamic> jsonEncodedLayout = {
    'x': 1.0,
    'y': 2.0,
    'w': 3.0,
    'h': 1000000000000.0,
    'surfaceId': 'first'
  };
  group('test encoding of types to JSON', () {
    test('encode SurfaceLayout to JSON', () {
      expect(layout.toJson(), equals(jsonEncodedLayout));
    });
    test('decode JSON to SufaceLayout', () {
      expect(SurfaceLayout.fromJson(jsonEncodedLayout), (layout));
    });
  });

  // TODO (djmurphy): StackLayout test
}
