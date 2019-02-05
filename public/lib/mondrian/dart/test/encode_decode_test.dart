// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.mondrian.dart/mondrian.dart';
import 'package:test/test.dart';

void main() {
  SurfaceLayout layout =
      SurfaceLayout(x: 1, y: 2, w: 3, h: 1000000000000, surfaceId: 'first');
  Map<String, dynamic> jsonEncodedLayout = {
    'x': 1,
    'y': 2,
    'w': 3,
    'h': 1000000000000,
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
