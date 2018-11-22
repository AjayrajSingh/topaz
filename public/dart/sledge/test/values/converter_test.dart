// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'dart:typed_data';

import 'package:lib.app.dart/logging.dart';
import 'package:sledge/src/document/values/converted_change.dart';
import 'package:sledge/src/document/values/converter.dart';
import 'package:test/test.dart';

import 'matchers.dart';

void main() {
  setupLogger();

  Converter<int> intConverter = new Converter<int>();
  Converter<bool> boolConverter = new Converter<bool>();
  Converter<double> doubleConverter = new Converter<double>();
  Converter<String> stringConverter = new Converter<String>();

  group('Correct convertions', () {
    test('int converter', () {
      expect(intConverter.deserialize(intConverter.serialize(0)), equals(0));
      expect(intConverter.deserialize(intConverter.serialize(23)), equals(23));
      expect(intConverter.deserialize(intConverter.serialize(-7)), equals(-7));
      expect(intConverter.deserialize(intConverter.serialize(113124324)),
          equals(113124324));

      const maxInt = (1 << 63) - 1;
      expect(intConverter.deserialize(intConverter.serialize(maxInt)),
          equals(maxInt));

      const minInt = 1 << 63;
      expect(intConverter.deserialize(intConverter.serialize(minInt)),
          equals(minInt));
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

    test('data converter', () {
      final conv = new MapToKVListConverter<String, int>();
      final longBuffer = new StringBuffer();
      for (int i = 0; i < 100; i++) {
        longBuffer.write('$i');
      }
      final long = longBuffer.toString(), short = 'aba';
      final change = new ConvertedChange<String, int>({long: 10, short: 1});
      final serializedChange = conv.serialize(change);
      expect(serializedChange.changedEntries[0].key.length <= 128 + 1, isTrue);
      final deserializedChange = conv.deserialize(serializedChange);
      expect(deserializedChange.changedEntries[short], equals(1));
      expect(deserializedChange.changedEntries[long], equals(10));
      final change2 = new ConvertedChange<String, int>(
          <String, int>{}, [short, long].toSet());
      final deserializedChange2 = conv.deserialize(conv.serialize(change2));
      expect(deserializedChange2.deletedKeys.length, equals(2));
      expect(deserializedChange2.deletedKeys.contains(short), isTrue);
      expect(deserializedChange2.deletedKeys.contains(long), isTrue);
    });
  });

  group('Exceptions', () {
    test('odd lengthInBytes', () {
      expect(() => stringConverter.deserialize(new Uint8List(1)),
          throwsInternalError);
    });
    test("double's length", () {
      for (int i = 0; i < 10; i++) {
        if (i != 8) {
          expect(() => doubleConverter.deserialize(new Uint8List(i)),
              throwsInternalError);
        }
      }
    });
    test('bool', () {
      for (int i = 0; i < 10; i++) {
        if (i != 1) {
          expect(() => boolConverter.deserialize(new Uint8List(i)),
              throwsInternalError);
        }
      }
      expect(() => boolConverter.deserialize(new Uint8List.fromList([2])),
          throwsInternalError);
      expect(() => boolConverter.deserialize(new Uint8List.fromList([-1])),
          throwsInternalError);
      expect(boolConverter.deserialize(new Uint8List.fromList([0])),
          equals(false));
      expect(
          boolConverter.deserialize(new Uint8List.fromList([1])), equals(true));
    });
  });
}
