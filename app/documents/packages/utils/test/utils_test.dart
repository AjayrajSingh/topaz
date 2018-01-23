// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';
import 'package:utils/utils.dart';

void main() {
  test('negative sizes', () {
    expect(prettifyFileSize(-1), equals('-1 bytes'));
  });

  test('zero size', () {
    expect(prettifyFileSize(0), equals('0 bytes'));
  });

  test('1 byte', () {
    expect(prettifyFileSize(1), equals('1 byte'));
  });
  test('2 bytes', () {
    expect(prettifyFileSize(2), equals('2 bytes'));
  });
  test('1000 bytes', () {
    expect(prettifyFileSize(1000), equals('1000 bytes'));
  });

  test('small kbytes', () {
    expect(prettifyFileSize(1536), equals('1.5 KB'));
  });
  test('big kbytes', () {
    expect(prettifyFileSize(550000), equals('537 KB'));
  });

  test('small mbytes', () {
    expect(prettifyFileSize(1200000), equals('1.1 MB'));
  });
  test('big mbytes', () {
    expect(prettifyFileSize(1024 * 1024 * 1023), equals('1023 MB'));
  });

  test('small gbytes', () {
    expect(prettifyFileSize(2000000000), equals('1.9 GB'));
  });
  test('big gbytes', () {
    expect(prettifyFileSize(1024 * 1024 * 1024 * 500), equals('500 GB'));
  });

  test('small tbytes', () {
    expect(prettifyFileSize(2000000000000), equals('1.8 TB'));
  });
  test('big tbytes', () {
    expect(prettifyFileSize(1024 * 1024 * 1024 * 500000), equals('488 TB'));
  });
}