// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.widgets.dart/model.dart';

class DriverExampleModel extends Model {
  /// Constructs model with an initial count of zero.
  DriverExampleModel() : _count = 0;

  int _count;
  int get count => _count;

  /// Increments the counter. If no args are supplied increases by one, else by
  /// the number `by`.
  void increment({int by}) {
    if (by == null) {
      _count++;
    } else {
      _count += by;
    }
    notifyListeners();
  }

  /// Decrements the counter. If no args are supplied decreases by one, else by
  /// the number `by`.
  void decrement({int by}) {
    if (by == null) {
      _count--;
    } else {
      _count -= by;
    }
    notifyListeners();
  }
}
