// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.fidl.examples.interfaces/geometry.fidl.dart';

void main(List args, Object request) {
  Point p = new Point();
  p.x = 1;
  p.y = 2;
  print('Point is $p');
}
