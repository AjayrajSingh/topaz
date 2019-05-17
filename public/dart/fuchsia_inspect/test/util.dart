// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:fuchsia_inspect/inspect.dart';
import 'package:fuchsia_inspect/src/vmo/block.dart';
import 'package:fuchsia_inspect/src/vmo/vmo_holder.dart';
import 'package:test/test.dart';
import 'package:zircon/zircon.dart';

class FakeVmo implements VmoHolder {
  /// The memory contents of this "VMO".
  final ByteData bytes;

  final Vmo _vmo = Vmo(null);

  @override
  Vmo get vmo => _vmo;

  /// Size of the "VMO".
  @override
  final int size;

  /// Creates non-shared (ByteData) memory to simulate VMO operations.
  FakeVmo(this.size) : bytes = ByteData(size);

  @override
  void beginWork() {}

  @override
  void commit() {}

  /// Writes to the "VMO".
  @override
  void write(int offset, ByteData data) {
    bytes.buffer.asUint8List().setAll(offset,
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }

  /// Reads from the "VMO".
  @override
  ByteData read(int offset, int size) {
    var reading = ByteData(size);
    reading.buffer
        .asUint8List()
        .setAll(0, bytes.buffer.asUint8List(offset, size));
    return reading;
  }

  /// Writes int64 to VMO.
  @override
  void writeInt64(int offset, int value) =>
      bytes.setInt64(offset, value, Endian.little);

  /// Writes int64 directly to VMO for immediate visibility.
  @override
  void writeInt64Direct(int offset, int value) => writeInt64(offset, value);

  /// Reads int64 from VMO.
  @override
  int readInt64(int offset) => bytes.getInt64(offset, Endian.little);
}

/// Returns the ascii code of this character.
int ascii(String char) {
  if (char.length != 1) {
    throw ArgumentError('char must be 1 character long.');
  }
  var code = char.codeUnitAt(0);
  if (code > 127) {
    throw ArgumentError("char wasn't ascii (code $code)");
  }
  return code;
}

/// returns the hex char corresponding to a 0..15 value.
String hexChar(int value) {
  if (value < 0 || value > 15) {
    throw ArgumentError('Bad value $value');
  }
  return value.toRadixString(16);
}

/// Compares contents, starting at [offset], with the hex values in [spec].
///
/// Valid chars in [spec] are:
///   ' ' (ignored completely)
///   _ x X (skips 4 bits)
///   0..9 a..f A..F (hex value of 4 bits)
///
/// [spec] is little-endian, which makes integer values look weird. If you
/// write 0x234 into memory, it'll be matched by '34 02' (or by 'x4_2')
void compare(FakeVmo vmo, int offset, String spec) {
  int nybble = offset * 2;
  for (int i = 0; i < spec.length; i++) {
    int rune = spec.codeUnitAt(i);
    if (rune == ascii(' ')) {
      continue;
    }
    if (rune == ascii('_') || rune == ascii('x') || rune == ascii('X')) {
      nybble++;
      continue;
    }
    int value;
    if (rune >= ascii('0') && rune <= ascii('9')) {
      value = rune - ascii('0');
    } else if (rune >= ascii('a') && rune <= ascii('f')) {
      value = rune - ascii('a') + 10;
    } else if (rune >= ascii('A') && rune <= ascii('F')) {
      value = rune - ascii('A') + 10;
    } else {
      throw ArgumentError('Illegal char "${String.fromCharCode(rune)}"');
    }
    int byte = nybble ~/ 2;
    int dataAtByte = vmo.bytes.getUint8(byte);
    int dataAtNybble = (nybble & 1 == 0) ? dataAtByte >> 4 : dataAtByte & 0xf;
    if (dataAtNybble != value) {
      expect(dataAtNybble, value,
          reason: 'byte[$byte] = ${dataAtByte.toRadixString(16)}. '
              'Nybble $nybble was ${dataAtNybble.toRadixString(16)} '
              'but expected ${value.toRadixString(16)}.');
    }
    nybble++;
  }
}

/// Writes block contents in hexadecimal, nicely formatted, to stdout.
///
/// This is very useful in debugging, so I'll leave it in although it's not
/// used in testing.
void dumpBlocks(FakeVmo vmo, {int startIndex = 0, int howMany32 = -1}) {
  int lastIndex = (howMany32 == -1)
      ? (vmo.bytes.lengthInBytes >> 4) - 1
      : startIndex + howMany32 - 1;
  stdout.writeln('Dumping blocks from $startIndex through $lastIndex');
  for (int index = startIndex; index <= lastIndex;) {
    String lowNybble(int offset) => hexChar(vmo.bytes.getUint8(offset) & 15);
    String highNybble(int offset) => hexChar(vmo.bytes.getUint8(offset) >> 4);
    stdout.write('${(index * 16).toRadixString(16).padLeft(3, '0')}: ');
    for (int byte = 0; byte < 8; byte++) {
      stdout
        ..write('${lowNybble(index * 16 + byte)} ')
        ..write('${highNybble(index * 16 + byte)} ');
    }
    int order = vmo.bytes.getUint8(index * 16) & 0xf;
    int numWords = 1 << (order + 1);
    String byteToHex(int offset) =>
        vmo.bytes.getUint8(offset).toRadixString(16).padLeft(2, '0');
    for (int word = 1; word < numWords; word++) {
      stdout.write('  ');
      for (int byte = 0; byte < 8; byte++) {
        stdout.write('${byteToHex(index * 16 + word * 8 + byte)} ');
      }
    }
    index += 1 << order;
    stdout.writeln('');
  }
}

/// Reads the property at [propertyIndex] out of [vmo], and returns the value.
ByteData readProperty(FakeVmo vmo, int propertyIndex) {
  final property = Block.read(vmo, propertyIndex);
  final totalLength = property.propertyTotalLength;
  final data = ByteData(totalLength);
  if (totalLength == 0) {
    return data;
  }
  var nextExtentIndex = property.propertyExtentIndex;
  int offset = 0;
  while (offset < totalLength) {
    final extent = Block.read(vmo, nextExtentIndex);
    int amountToCopy = min(totalLength - offset, extent.payloadSpaceBytes);
    data.buffer.asUint8List().setRange(offset, offset + amountToCopy,
        extent.payloadBytes.buffer.asUint8List());
    offset += amountToCopy;
    nextExtentIndex = extent.nextExtent;
  }
  return data;
}

/// Returns the name index of [node] in [vmo].
int readNameIndex(FakeVmo vmo, Node node) =>
    Block.read(vmo, node.index).nameIndex;

/// Returns the int value of [property] in [vmo].
int readInt(FakeVmo vmo, IntProperty property) =>
    Block.read(vmo, property.index).intValue;

/// Returns the double value of [property] in [vmo].
double readDouble(FakeVmo vmo, DoubleProperty property) =>
    Block.read(vmo, property.index).doubleValue;

/// A matcher that matches ByteData properties as unit8 lists.
Matcher equalsByteData(ByteData data) => _EqualsByteData(data);

class _EqualsByteData extends Matcher {
  final ByteData _other;

  const _EqualsByteData(this._other);

  @override
  bool matches(dynamic item, _) {
    if (item is! ByteData) {
      return false;
    }

    var listEquals = ListEquality().equals;

    ByteData byteData = item;
    return listEquals(
        byteData.buffer.asUint8List(), _other.buffer.asUint8List());
  }

  @override
  Description describe(Description description) =>
      description.add('buffer as uint8 list: ${_other.buffer.asUint8List()}');

  @override
  Description describeMismatch(
      dynamic item, Description mismatchDescription, _, __) {
    if (item is! ByteData) {
      return mismatchDescription.add('$item is not of type ByteData');
    }

    ByteData byteData = item;
    return mismatchDescription
        .replace('buffer as uint8 list: ${byteData.buffer.asUint8List()}');
  }
}
