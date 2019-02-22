// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports, unused_import

// Since we don't have tests yet, import everything to make sure it at least compiles.
import 'package:test/test.dart';
import 'package:fuchsia_inspect/inspect.dart';
import 'package:fuchsia_inspect/src/inspect.dart';
import 'package:fuchsia_inspect/src/vmo_format.dart';
import 'package:fuchsia_inspect/src/vmo_heap.dart';
import 'package:fuchsia_inspect/src/vmo_holder.dart';
import 'package:fuchsia_inspect/src/vmo_writer.dart';

void main() {
  group('placeholder for tests', () {
    test('trivial', () {
      expect(41, equals(41));
    });
  });
}
