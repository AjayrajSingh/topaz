// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:convert';
import 'dart:typed_data';

import 'package:fidl_dart_fidl_json_test_fidl_json/json.dart';
import 'package:fidl_test_dart_fidl_json/fidl.dart';
import 'package:test/test.dart';

void main() {
  // Ensure enum encode/decode.
  test('test_enum', () async {
    const ExampleEnum sourceEnum = ExampleEnum.val1;

    expect(
        sourceEnum,
        ExampleEnumConverter.fromJson(
            jsonDecode(jsonEncode(ExampleEnumConverter.toJson(sourceEnum)))));
  });

  // Ensure struct encode/decode.
  test('test_struct', () async {
    ExampleStruct struct = ExampleStruct(
        bar: 1,
        foo: 'test',
        structs: null,
        vals: ['foo', 'bar'],
        integers: Uint32List.fromList([1, 2]));

    expect(
        struct,
        ExampleStructConverter.fromJson(
            jsonDecode(jsonEncode(ExampleStructConverter.toJson(struct)))));

    ExampleStruct structWithVector = ExampleStruct(
        bar: 1,
        foo: 'test',
        structs: [ExampleStruct2(baz: 2)],
        vals: ['foo'],
        integers: Uint32List.fromList([3, 4]));
    expect(
        structWithVector,
        ExampleStructConverter.fromJson(jsonDecode(
            jsonEncode(ExampleStructConverter.toJson(structWithVector)))));
  });

  // Ensure union encode/decode.
  test('test_union', () async {
    const ExampleUnion exampleUnion = ExampleUnion.withStruct1(ExampleStruct(
        bar: 1, foo: 'test', structs: null, vals: null, integers: null));

    expect(
        exampleUnion,
        ExampleUnionConverter.fromJson(jsonDecode(
            jsonEncode(ExampleUnionConverter.toJson(exampleUnion)))));
  });
}
