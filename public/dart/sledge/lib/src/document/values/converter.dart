// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'key_value.dart';

/// Interface for converting T to ByteData and back.
abstract class Converter<T> {
  /// Returns a converter of type T.
  factory Converter() {
    final result = _converters[T];
    if (result == null) {
      throw new UnsupportedError('No converter found for type $T.');
    }
    return result;
  }

  /// Converts from ByteData to T.
  T deserialize(final ByteData x);

  /// Converts from T to ByteData.
  ByteData serialize(final T x);
}

/// Class for converting Map<K, V> to List<KeyValue> and back.
class DataConverter<K, V> {
  final Converter _keyConverter, _valueConverter;

  /// Constructor.
  DataConverter()
      : _keyConverter = new Converter<K>(),
        _valueConverter = new Converter<V>();

  /// Converts from List<KeyValue> to Map<K, V>.
  Map<K, V> deserialize(final List<KeyValue> input) {
    final Map<K, V> result = <K, V>{};
    for (var keyValue in input) {
      result[_keyConverter.deserialize(keyValue.key)] =
          _valueConverter.deserialize(keyValue.value);
    }
    return result;
  }

  /// Converts from Map<K, V> to List<KeyValue>.
  List<KeyValue> serialize(final Map<K, V> input) {
    final List<KeyValue> result = <KeyValue>[];
    for (var key in input.keys) {
      result.add(new KeyValue(
          _keyConverter.serialize(key), _valueConverter.serialize(input[key])));
    }
    return result;
  }
}

/// Converter for string.
class StringConverter implements Converter<String> {
  /// Constructor.
  const StringConverter();

  @override
  String deserialize(final ByteData x) {
    return new String.fromCharCodes(x.buffer.asUint16List());
  }

  @override
  ByteData serialize(final String x) {
    return new Uint16List.fromList(x.codeUnits).buffer.asByteData();
  }
}

// TODO: rewrite this converter.
// int in Dart is an arbitrary large integer.
// So we can't just use get/setInt64() without checks and limitations.
/// Converter for Int.
class IntConverter implements Converter<int> {
  /// Constructor.
  const IntConverter();

  @override
  int deserialize(final ByteData x) {
    final s = new StringConverter().deserialize(x);
    return int.parse(s);
  }

  @override
  ByteData serialize(final int x) {
    return new StringConverter().serialize(x.toString());
  }
}

/// Converter for double.
class DoubleConverter implements Converter<double> {
  /// Constructor.
  const DoubleConverter();

  @override
  double deserialize(final ByteData x) {
    return x.getFloat64(0);
  }

  @override
  ByteData serialize(final double x) {
    return new ByteData(8)..setFloat64(0, x);
  }
}

const _converters = const <Type, Converter>{
  int: const IntConverter(),
  String: const StringConverter(),
  double: const DoubleConverter()
};
