// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'dart:typed_data';

import 'package:sledge/src/document/values/converter.dart';
import 'package:sledge/src/document/values/key_value.dart';
import 'package:test/test.dart';

void main() {
  Converter<int> intConverter = new Converter<int>();
  Converter<bool> boolConverter = new Converter<bool>();
  Converter<double> doubleConverter = new Converter<double>();
  Converter<String> stringConverter = new Converter<String>();

  group('Correct convertions', () {
    // TODO: add MAX_INT, MIN_INT.
    test('int converter', () {
      expect(intConverter.deserialize(intConverter.serialize(0)), equals(0));
      expect(intConverter.deserialize(intConverter.serialize(23)), equals(23));
      expect(intConverter.deserialize(intConverter.serialize(-7)), equals(-7));
      expect(intConverter.deserialize(intConverter.serialize(113124324)),
          equals(113124324));
    });

    test('bool converter', () {
      expect(boolConverter.deserialize(boolConverter.serialize(false)),
          equals(false));
      expect(boolConverter.deserialize(boolConverter.serialize(true)),
          equals(true));
    });

    test('double converter', () {
      expect(doubleConverter.deserialize(doubleConverter.serialize(0.0)),
          equals(0.0));
      expect(doubleConverter.deserialize(doubleConverter.serialize(23.5)),
          equals(23.5));
      expect(doubleConverter.deserialize(doubleConverter.serialize(-0.001)),
          equals(-0.001));
    });

    test('string converter', () {
      expect(stringConverter.deserialize(stringConverter.serialize('')),
          equals(''));
      expect(stringConverter.deserialize(stringConverter.serialize('foo')),
          equals('foo'));
      expect(
          stringConverter.deserialize(stringConverter.serialize('"?123 x  ')),
          equals('"?123 x  '));
    });
  });

  group('Exceptions', () {
    test('odd lengthInBytes', () {
      expect(() => stringConverter.deserialize(new Uint8List(1)),
          throwsFormatException);
    });
    test("double's length", () {
      for (int i = 0; i < 10; i++) {
        if (i != 8) {
          expect(() => doubleConverter.deserialize(new Uint8List(i)),
              throwsFormatException);
        }
      }
    });
    test('bool', () {
      for (int i = 0; i < 10; i++) {
        if (i != 1) {
          expect(() => boolConverter.deserialize(new Uint8List(i)),
              throwsFormatException);
        }
      }
      expect(() => boolConverter.deserialize(new Uint8List.fromList([2])),
          throwsFormatException);
      expect(() => boolConverter.deserialize(new Uint8List.fromList([-1])),
          throwsFormatException);
      expect(boolConverter.deserialize(new Uint8List.fromList([0])),
          equals(false));
      expect(
          boolConverter.deserialize(new Uint8List.fromList([1])), equals(true));
    });
  });
}
