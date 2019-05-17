// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:typed_data';

import 'package:fuchsia_inspect/src/vmo/bitfield64.dart';
import 'package:fuchsia_inspect/src/vmo/block.dart';
import 'package:fuchsia_inspect/src/vmo/util.dart';
import 'package:fuchsia_inspect/src/vmo/vmo_fields.dart';
import 'package:fuchsia_inspect/src/vmo/vmo_holder.dart';
import 'package:fuchsia_inspect/src/vmo/vmo_writer.dart';
import 'package:test/test.dart';

import '../util.dart';

void main() {
  group('vmo_writer operations work:', () {
    test('Init VMO writes correctly to the VMO', () {
      final vmo = FakeVmo(256);
      VmoWriter(vmo);
      final f = hexChar(BlockType.free.value);
      final h = hexChar(BlockType.header.value);
      final n = hexChar(BlockType.nodeValue.value);
      final u = hexChar(BlockType.nameUtf8.value);
      String byte(char) => ascii(char).toRadixString(16).padLeft(2, '0');
      final r = byte('r');
      final t = byte('t');
      final o = byte('o');
      compare(vmo, 0x00, '$h 0 000000 494E5350  00000000 00000000');
      compare(vmo, 0x10, '$n 0 000000 20000000  00000000 00000000');
      compare(vmo, 0x20, '$u 1 040000 00000000  $r$o$o$t 00000000');
      compare(vmo, 0x30, '0  0 000000 00000000  00000000 00000000');
      compare(vmo, 0x40, '$f 1 0_0000 00000000  00000000 00000000');
      compare(vmo, 0x50, '0  0 000000 00000000  00000000 00000000');
      compare(vmo, 0x60, '$f 1 0_0000 00000000  00000000 00000000');
      compare(vmo, 0x70, '0  0 000000 00000000  00000000 00000000');
      expect(countFreeBlocks(vmo), 6);
    });

    test('failed createNode leaves VMO sequence number even (valid VMO)', () {
      final vmo = FakeVmo(64); // No space for anything
      final writer = VmoWriter(vmo);
      final h = hexChar(BlockType.header.value);
      writer.createNode(writer.rootNode, 'child');
      compare(vmo, 0x00, '$h 0 000000 494E5350  02000000 00000000');
      writer.createProperty(writer.rootNode, 'property');
    });

    test('failed createProperty leaves VMO sequence number even (valid VMO)',
        () {
      final vmo = FakeVmo(64); // No space for anything
      final writer = VmoWriter(vmo);
      final h = hexChar(BlockType.header.value);
      writer.createProperty(writer.rootNode, 'property');
      compare(vmo, 0x00, '$h 0 000000 494E5350  02000000 00000000');
    });

    test('failed createMetric leaves VMO sequence number even (valid VMO)', () {
      final vmo = FakeVmo(64); // No space for anything
      final writer = VmoWriter(vmo);
      final h = hexChar(BlockType.header.value);
      writer.createMetric(writer.rootNode, 'metric', 0);
      compare(vmo, 0x00, '$h 0 000000 494E5350  02000000 00000000');
    });

    test('make, modify, and free Node', () {
      final vmo = FakeVmo(1024);
      final checker = Checker(vmo);
      final writer = VmoWriter(vmo);
      checker.check(0, []);
      final child = writer.createNode(writer.rootNode, 'child');
      checker.check(2, [
        Test(_nameFor(vmo, child), toByteData('child')),
        Test(writer.rootNode, 1)
      ]);
      writer.deleteEntity(child);
      // Deleting a node without children should free it and its name.
      // root node should have 0 children.
      checker.check(-2, [Test(writer.rootNode, 0)]);
    });

    test('make, modify, and free IntMetric', () {
      final vmo = FakeVmo(1024);
      final checker = Checker(vmo);
      final writer = VmoWriter(vmo);
      checker.check(0, []);
      final intMetric = writer.createMetric(writer.rootNode, 'intMetric', 1);
      checker.check(2, [
        Test(_nameFor(vmo, intMetric), toByteData('intMetric')),
        Test(intMetric, 1, reason: 'int value wrong'),
        Test(writer.rootNode, 1, reason: 'childCount wrong')
      ]);
      writer.addMetric(intMetric, 2);
      checker.check(0, [Test(intMetric, 3)]);
      writer.subMetric(intMetric, 4);
      checker.check(0, [Test(intMetric, -1)]);
      writer.setMetric(intMetric, 2);
      checker.check(0, [Test(intMetric, 2)]);
      writer.deleteEntity(intMetric);
      checker.check(-2, [Test(writer.rootNode, 0)]);
    });

    test('make, modify, and free DoubleMetric', () {
      final vmo = FakeVmo(1024);
      final checker = Checker(vmo);
      final writer = VmoWriter(vmo);
      checker.check(0, []);
      final doubleMetric =
          writer.createMetric(writer.rootNode, 'doubleMetric', 1.5);
      checker.check(2, [
        Test(_nameFor(vmo, doubleMetric), toByteData('doubleMetric')),
        Test(doubleMetric, 1.5, reason: 'double value wrong'),
        Test(writer.rootNode, 1, reason: 'childCount wrong')
      ]);
      writer.addMetric(doubleMetric, 2.0);
      checker.check(0, [Test(doubleMetric, 3.5)]);
      writer.subMetric(doubleMetric, 4.0);
      checker.check(0, [Test(doubleMetric, -0.5)]);
      writer.setMetric(doubleMetric, 1.5);
      checker.check(0, [Test(doubleMetric, 1.5)]);
      writer.deleteEntity(doubleMetric);
      checker.check(-2, [Test(writer.rootNode, 0)]);
    });

    test('make, modify, and free Property', () {
      final vmo = FakeVmo(1024);
      final checker = Checker(vmo);
      final writer = VmoWriter(vmo);
      checker.check(0, []);

      final property = writer.createProperty(writer.rootNode, 'prop');
      checker.check(2, [
        Test(_nameFor(vmo, property), toByteData('prop')),
        Test(writer.rootNode, 1)
      ]);
      final bytes = ByteData(8)..setFloat64(0, 1.23);
      writer.setProperty(property, bytes);
      checker.check(1, [Test(_extentFor(vmo, property), bytes)]);
      writer.deleteEntity(property);
      // Property, its extent, and its name should be freed. Its parent should
      // have one fewer children (0 in this case).
      checker.check(-3, [Test(writer.rootNode, 0)]);
    });

    test('Node delete permutations', () {
      final vmo = FakeVmo(1024);
      final checker = Checker(vmo);
      final writer = VmoWriter(vmo);
      checker.check(0, []);
      final parent = writer.createNode(writer.rootNode, 'parent');
      checker.check(2, [Test(writer.rootNode, 1)]);
      final child = writer.createNode(parent, 'child');
      checker.check(2, [Test(writer.rootNode, 1), Test(parent, 1)]);
      final metric = writer.createMetric(child, 'metric', 1);
      checker.check(2, [Test(child, 1), Test(parent, 1)]);
      writer.deleteEntity(child);
      // Now child should be a tombstone; only its name should be freed.
      checker.check(-1, [Test(child, 1), Test(parent, 0)]);
      writer.deleteEntity(parent);
      // Parent, plus its name, should be freed; root should have no children.
      checker.check(-2, [Test(writer.rootNode, 0)]);
      writer.deleteEntity(metric);
      // Metric, its name, and child should be freed.
      checker.check(-3, []);
      // Make sure we can still create nodes on the root
      final newMetric =
          writer.createMetric(writer.rootNode, 'newIntMetric', 42);
      checker.check(2, [
        Test(_nameFor(vmo, newMetric), toByteData('newIntMetric')),
        Test(newMetric, 42),
        Test(writer.rootNode, 1)
      ]);
    });

    test('String property has string flag bits', () {
      final vmo = FakeVmo(512);
      final writer = VmoWriter(vmo);
      final property = writer.createProperty(writer.rootNode, 'property');
      writer.setProperty(property, 'abc');
      expect(Block.read(vmo, property).propertyFlags, propertyUtf8Flag);
    });

    test('Binary property has binary flag bits', () {
      final vmo = FakeVmo(512);
      final writer = VmoWriter(vmo);
      final property = writer.createProperty(writer.rootNode, 'property');
      writer.setProperty(property, ByteData(3));
      expect(Block.read(vmo, property).propertyFlags, propertyBinaryFlag);
    });

    test('Invalid property-set value type throws ArgumentError', () {
      final vmo = FakeVmo(512);
      final writer = VmoWriter(vmo);
      final property = writer.createProperty(writer.rootNode, 'property');
      expect(() => writer.setProperty(property, 3),
          throwsA(const TypeMatcher<ArgumentError>()));
    });

    test('Large properties', () {
      final vmo = FakeVmo(512);
      final writer = VmoWriter(vmo);
      int unique = 2;
      void fill(ByteData data) {
        for (int i = 0; i < data.lengthInBytes; i += 2) {
          data.setUint16(i, unique);
          unique += 1;
        }
      }

      final data0 = ByteData(0);
      final data200 = ByteData(200);
      fill(data200);
      final data230 = ByteData(230);
      fill(data230);
      final data530 = ByteData(530);
      fill(data530);
      final property = writer.createProperty(writer.rootNode, 'property');
      expect(readProperty(vmo, property), equalsByteData(data0));

      writer.setProperty(property, data200);
      expect(readProperty(vmo, property), equalsByteData(data200));

      // There isn't space for 200+230, but the set to 230 should still work.
      writer.setProperty(property, data230);
      expect(readProperty(vmo, property), equalsByteData(data230));

      // The set to 530 should fail and leave an empty property.
      writer.setProperty(property, data530);
      expect(readProperty(vmo, property), equalsByteData(data0));

      // And after all that, 200 should still work.
      writer.setProperty(property, data200);
      expect(readProperty(vmo, property), equalsByteData(data200));
    });
  });
}

/// Counts the free blocks in this VMO.
///
/// Assumes all free blocks are 32-byte (order 1) and all blocks are 32-byte or
/// smaller.
///
/// NOTE: This is O(n) in the size of the VMO. Be careful not to do
/// n^2 algorithms on large VMO's.
int countFreeBlocks(VmoHolder vmo) {
  var blocksFree = 0;
  for (int i = 0; i < vmo.size; i += 32) {
    if (Bitfield64(vmo.readInt64(i)).read(typeBits) == BlockType.free.value) {
      blocksFree++;
    }
  }
  return blocksFree;
}

/// Gets the index of the [BlockType.name] block of the Value at [index].
int _nameFor(vmo, index) => Block.read(vmo, index).nameIndex;

/// Gets the index of the first [BlockType.extent] block of the Value at
/// [index].
int _extentFor(vmo, index) => Block.read(vmo, index).propertyExtentIndex;

/// Test holds values for use in [Checker.check()].
class Test {
  final int index;
  final String reason;
  final dynamic value;
  Test(this.index, this.value, {this.reason});
}

/// Checker tracks activity on a VMO and makes sure its state is correct.
///
/// check() must be called once after VmoWriter initialization, and once after
/// every operation that changes the VMO lock.
class Checker {
  FakeVmo _vmo;
  int nextLock = 0;
  int expectedFree;
  Checker(this._vmo) {
    expectedFree = (_vmo.bytes.lengthInBytes >> 5) - 2;
  }

  void testPayload(Test test) {
    int payloadOffset = test.index * 16 + 8;
    var commonString = '${payloadOffset.toRadixString(16)} '
        '(index ${(payloadOffset - 8) >> 4})';
    if (test.reason != null) {
      commonString += ' because ${test.reason}';
    }
    final value = test.value;
    if (value is int) {
      int intValue = value;
      expect(_vmo.bytes.getUint64(payloadOffset, Endian.little), intValue,
          reason: 'int at $commonString');
    } else if (value is double) {
      double doubleValue = value;
      expect(_vmo.bytes.getFloat64(payloadOffset, Endian.little), doubleValue,
          reason: 'double at $commonString');
    } else if (value is ByteData) {
      ByteData byteData = value;
      expect(
          _vmo.bytes.buffer
              .asUint8List(payloadOffset, byteData.buffer.lengthInBytes),
          byteData.buffer.asUint8List(),
          reason: 'ByteData at $commonString');
    } else {
      throw ArgumentError("I can't handle value type ${value.runtimeType}");
    }
  }

  void check(int usedBlocks, List<Test> checks) {
    expect(_vmo.bytes.getInt64(8, Endian.little), nextLock,
        reason: 'Lock out of sync (call check() once per operation)');
    nextLock += 2;
    expectedFree -= usedBlocks;
    expect(countFreeBlocks(_vmo), expectedFree);
    checks.forEach(testPayload);
  }
}
