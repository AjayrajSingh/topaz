// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'dart:typed_data';

import 'package:fuchsia_logger/logger.dart';
import 'package:sledge/src/document/values/converted_change.dart';
import 'package:sledge/src/document/values/converter.dart';
import 'package:test/test.dart';

import 'matchers.dart';

void _testSerializationAndDeserialization<T>(T value) {
  Converter<T> converter = Converter<T>();
  expect(converter.deserialize(converter.serialize(value)), equals(value));
}

void _testValues<T>(List<T> values) {
  values.forEach(_testSerializationAndDeserialization);
}

void main() {
  setupLogger();

  final boolConverter = Converter<bool>();
  final doubleConverter = Converter<double>();
  final numConverter = Converter<num>();
  final stringConverter = Converter<String>();

  group('Correct convertions', () {
    test('int converter', () {
      _testValues<int>(<int>[0, 23, -7, 113124324, (1 << 63) - 1, 1 << 63]);
    });

    test('bool converter', () {
      _testValues<bool>(<bool>[false, true]);
    });

    test('double converter', () {
      _testValues<double>(<double>[
        0.0,
        0,
        23.5,
        -0.001,
        double.negativeInfinity,
        double.maxFinite
      ]);
      // expect/equals does not work with NaN.
      expect(
          doubleConverter
              .deserialize(doubleConverter.serialize(double.nan))
              .isNaN,
          equals(true));
    });

    test('num converter', () {
      _testValues<num>(<num>[
        0.0,
        0,
        23.5,
        -0.001,
        113124324,
        double.negativeInfinity,
        double.maxFinite
      ]);
      // expect/equals does not work with NaN.
      expect(numConverter.deserialize(numConverter.serialize(double.nan)).isNaN,
          equals(true));
    });

    test('string converter', () {
      _testValues<String>(<String>['', 'foo', '?123 x  ']);
    });

    test('data converter', () {
      final conv = MapToKVListConverter<String, int>();
      final longBuffer = StringBuffer();
      for (int i = 0; i < 100; i++) {
        longBuffer.write('$i');
      }
      final long = longBuffer.toString(), short = 'aba';
      final change = ConvertedChange<String, int>({long: 10, short: 1});
      final serializedChange = conv.serialize(change);
      expect(serializedChange.changedEntries[0].key.length <= 128 + 1, isTrue);
      final deserializedChange = conv.deserialize(serializedChange);
      expect(deserializedChange.changedEntries[short], equals(1));
      expect(deserializedChange.changedEntries[long], equals(10));
      final change2 = ConvertedChange<String, int>(
          <String, int>{}, <String>{short, long});
      final deserializedChange2 = conv.deserialize(conv.serialize(change2));
      expect(deserializedChange2.deletedKeys.length, equals(2));
      expect(deserializedChange2.deletedKeys.contains(short), isTrue);
      expect(deserializedChange2.deletedKeys.contains(long), isTrue);
    });
  });

  group('Exceptions', () {
    test('odd lengthInBytes', () {
      expect(() => stringConverter.deserialize(Uint8List(1)),
          throwsInternalError);
    });
    test("double's length", () {
      for (int i = 0; i < 10; i++) {
        if (i != 8) {
          expect(() => doubleConverter.deserialize(Uint8List(i)),
              throwsInternalError);
        }
      }
    });
    test('bool', () {
      for (int i = 0; i < 10; i++) {
        if (i != 1) {
          expect(() => boolConverter.deserialize(Uint8List(i)),
              throwsInternalError);
        }
      }
      expect(() => boolConverter.deserialize(Uint8List.fromList([2])),
          throwsInternalError);
      expect(() => boolConverter.deserialize(Uint8List.fromList([-1])),
          throwsInternalError);
      expect(boolConverter.deserialize(Uint8List.fromList([0])),
          equals(false));
      expect(
          boolConverter.deserialize(Uint8List.fromList([1])), equals(true));
    });
  });
}
