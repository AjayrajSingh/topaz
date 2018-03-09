// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:zircon/zircon.dart';

void main() {
  test('fromFile', () {
    const String fuchsia = 'Fuchsia';
    File f = new File('tmp/testdata')
      ..createSync()
      ..writeAsStringSync(fuchsia);
    String readFuchsia = f.readAsStringSync();
    expect(readFuchsia, equals(fuchsia));

    SizedVmo fileVmo = new SizedVmo.fromFile('tmp/testdata');
    Uint8List fileData = fileVmo.map();
    String fileString = utf8.decode(fileData.sublist(0, fileVmo.size));
    expect(fileString, equals(fuchsia));
  });
}
