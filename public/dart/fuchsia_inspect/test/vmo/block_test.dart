// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:typed_data';

import 'package:fuchsia_inspect/src/vmo/block.dart';
import 'package:fuchsia_inspect/src/vmo/util.dart';
import 'package:fuchsia_inspect/src/vmo/vmo_fields.dart';
import 'package:test/test.dart';

import '../util.dart';

void main() {
  group('Block', () {
    test('accepts state (type) correctly', () {
      _accepts('lock/unlock', [BlockType.header], (block) {
        block.lock();
        block.unlock();
      });
      _accepts(
          'becomeRoot', [BlockType.reserved], (block) => block.becomeRoot());
      _accepts(
          'becomeNode', [BlockType.anyValue], (block) => block.becomeNode());
      _accepts('becomeProperty', [BlockType.anyValue],
          (block) => block.becomeProperty());
      _accepts('setChildren', [BlockType.nodeValue, BlockType.tombstone],
          (block) => block.childCount = 0);
      _accepts('getChildren', [BlockType.nodeValue, BlockType.tombstone],
          (block) => block.childCount);

      _accepts('setPropertyTotalLength', [BlockType.propertyValue],
          (block) => block.propertyTotalLength = 0);
      _accepts('getPropertyTotalLength', [BlockType.propertyValue],
          (block) => block.propertyTotalLength);
      _accepts('setPropertyExtentIndex', [BlockType.propertyValue],
          (block) => block.propertyExtentIndex = 0);
      _accepts('getPropertyExtentIndex', [BlockType.propertyValue],
          (block) => block.propertyExtentIndex);
      _accepts('setPropertyFlags', [BlockType.propertyValue],
          (block) => block.propertyFlags = 0);
      _accepts('getPropertyFlags', [BlockType.propertyValue],
          (block) => block.propertyFlags);

      _accepts('becomeTombstone', [BlockType.nodeValue],
          (block) => block.becomeTombstone());
      _accepts('becomeReserved', [BlockType.free],
          (block) => block.becomeReserved());
      _accepts('nextFree', [BlockType.free], (block) => block.nextFree);
      _accepts('becomeValue', [BlockType.reserved],
          (block) => block.becomeValue(nameIndex: 1, parentIndex: 2));
      _accepts(
          'nameIndex',
          [
            BlockType.nodeValue,
            BlockType.anyValue,
            BlockType.propertyValue,
            BlockType.intValue,
            BlockType.doubleValue
          ],
          (block) => block.nameIndex);
      _accepts(
          'parentIndex',
          [
            BlockType.nodeValue,
            BlockType.anyValue,
            BlockType.propertyValue,
            BlockType.intValue,
            BlockType.doubleValue
          ],
          (block) => block.parentIndex);
      _accepts('becomeDoubleMetric', [BlockType.anyValue],
          (block) => block.becomeDoubleMetric(0.0));
      _accepts('becomeIntMetric', [BlockType.anyValue],
          (block) => block.becomeIntMetric(0));
      _accepts('intValueGet', [BlockType.intValue], (block) => block.intValue);
      _accepts(
          'intValueSet', [BlockType.intValue], (block) => block.intValue = 0);
      _accepts('doubleValueGet', [BlockType.doubleValue],
          (block) => block.doubleValue);
      _accepts('doubleValueSet', [BlockType.doubleValue],
          (block) => block.doubleValue = 0.0);
      _accepts('becomeName', [BlockType.reserved],
          (block) => block.becomeName('foo'));
      _accepts('extentIndexSet', [BlockType.propertyValue],
          (block) => block.propertyExtentIndex = 0);
      _accepts(
          'nextExtentGet', [BlockType.extent], (block) => block.nextExtent);
    });

    test('can read, including payload bits', () {
      final vmo = FakeVmo(32);
      vmo.bytes
        ..setUint8(0, 0x01 | (BlockType.propertyValue.value << 4))
        ..setUint8(1, 0x14) // Parent index should be 0x14
        ..setUint8(4, 0x20) // Name index should be 0x32. 4..7 bits of
        ..setUint8(5, 0x03) //   byte 4 + (0..3 bits of byte 5) << 4
        ..setUint8(8, 0x7f) // Length should be 0x7f
        ..setUint8(12, 0x0a) // Extent
        ..setUint8(15, 0xb0); // Flags 0xb
      compare(
          vmo,
          0,
          '${hexChar(BlockType.propertyValue.value)} 1'
          '14 00 00  20 03 00 00  7f00 0000 0a00 00b0');
      final block = Block.read(vmo, 0);
      expect(block.size, 32);
      expect(block.type.value, BlockType.propertyValue.value);
      expect(block.parentIndex, 0x14);
      expect(block.nameIndex, 0x32);
      expect(block.propertyTotalLength, 0x7f);
      expect(block.propertyExtentIndex, 0xa);
      expect(block.propertyFlags, 0xb);
    });

    test('can read, including payload bytes', () {
      final vmo = FakeVmo(32);
      vmo.bytes
        ..setUint8(0, 0x01 | (BlockType.nameUtf8.value << 4))
        ..setUint8(1, 0x02) // Set length to 2
        ..setUint8(8, 0x41) // 'a'
        ..setUint8(9, 0x42); // 'b'
      compare(
          vmo,
          0,
          '${hexChar(BlockType.nameUtf8.value)} 1'
          '02 00 00 0000 0000  4142 0000 0000 0000 0000');
      final block = Block.read(vmo, 0);
      expect(block.size, 32);
      expect(block.type.value, BlockType.nameUtf8.value);
      expect(block.payloadBytes.getUint8(0), 0x41);
      expect(block.payloadBytes.getUint8(1), 0x42);
    });
  });

  group('Block operations write to VMO correctly:', () {
    test('Creating, locking, and unlocking the VMO header', () {
      final vmo = FakeVmo(32);
      final block = Block.create(vmo, 0)..becomeHeader();
      compare(
          vmo,
          0,
          '${hexChar(BlockType.header.value)} 0'
          '00 0000 49 4E 53 50  0000 0000 0000 0000');
      block.lock();
      compare(
          vmo,
          0,
          '${hexChar(BlockType.header.value)} 0'
          '00 0000 49 4E 53 50  0100 0000 0000 0000');
      block.unlock();
      compare(
          vmo,
          0,
          '${hexChar(BlockType.header.value)} 0'
          '00 0000 49 4E 53 50  0200 0000 0000 0000');
    });

    test('Becoming the special root node', () {
      final vmo = FakeVmo(64);
      Block.create(vmo, 1).becomeRoot();
      compare(vmo, 16,
          '${hexChar(BlockType.nodeValue.value)} 0 00 0000 2000 0000 0000');
    });

    test('Becoming and modifying an intValue via free, reserved, anyValue', () {
      final vmo = FakeVmo(64);
      final block = Block.create(vmo, 2)..becomeFree(5);
      compare(vmo, 32, '${hexChar(BlockType.free.value)} 1 05 00 00 0000 0000');
      expect(block.nextFree, 5);
      block.becomeReserved();
      compare(vmo, 32, '${hexChar(BlockType.reserved.value)} 1');
      block.becomeValue(parentIndex: 0xbc, nameIndex: 0x7d);
      compare(vmo, 32,
          '${hexChar(BlockType.anyValue.value)} 1 bc 00 00 d0 07 00 00');
      block.becomeIntMetric(0xbeef);
      compare(vmo, 32,
          '${hexChar(BlockType.intValue.value)} 1 bc 00 00 d0 07 00 00 efbe');
      block.intValue += 1;
      compare(vmo, 32,
          '${hexChar(BlockType.intValue.value)} 1 bc 00 00 d0 07 00 00 f0be');
    });

    test('Becoming a nodeValue and then a tombstone', () {
      final vmo = FakeVmo(64);
      final block = Block.create(vmo, 2)
        ..becomeFree(5)
        ..becomeReserved()
        ..becomeValue(parentIndex: 0xbc, nameIndex: 0x7d)
        ..becomeNode();
      compare(vmo, 32,
          '${hexChar(BlockType.nodeValue.value)} 1 bc 00 00 d0 07 00 00 0000');
      block.childCount += 1;
      compare(vmo, 32,
          '${hexChar(BlockType.nodeValue.value)} 1 bc 00 00 d0 07 00 00 0100');
      block.becomeTombstone();
      compare(vmo, 32,
          '${hexChar(BlockType.tombstone.value)} 1 bc 00 00 d0 07 00 00 0100');
    });

    test('Becoming and modifying doubleValue', () {
      final vmo = FakeVmo(64);
      final block = Block.create(vmo, 2)
        ..becomeFree(5)
        ..becomeReserved()
        ..becomeValue(parentIndex: 0xbc, nameIndex: 0x7d)
        ..becomeDoubleMetric(1.0);
      compare(vmo, 32,
          '${hexChar(BlockType.doubleValue.value)} 1 bc 00 00 d0 07 00 00 ');
      expect(vmo.bytes.getFloat64(40, Endian.little), 1.0);
      block.doubleValue++;
      expect(vmo.bytes.getFloat64(40, Endian.little), 2.0);
    });

    test('Becoming and modifying a propertyValue', () {
      final vmo = FakeVmo(64);
      final block = Block.create(vmo, 2)
        ..becomeFree(5)
        ..becomeReserved()
        ..becomeValue(parentIndex: 0xbc, nameIndex: 0x7d)
        ..becomeProperty();
      compare(
          vmo,
          32,
          '${hexChar(BlockType.propertyValue.value)} 1 bc 00 00 d0 07 00 00 '
          '00 00 00 00  00 00 00 00');
      block
        ..propertyExtentIndex = 0x35
        ..propertyTotalLength = 0x17b
        ..propertyFlags = 0xa;
      compare(
          vmo,
          32,
          '${hexChar(BlockType.propertyValue.value)} 1 bc 00 00 d0 07 00 00 '
          '7b 01 00 00  35 00 00 a0');
      expect(block.propertyTotalLength, 0x17b);
      expect(block.propertyExtentIndex, 0x35);
      expect(block.propertyFlags, 0xa);
    });

    test('Becoming a name', () {
      final vmo = FakeVmo(64);
      final block = Block.create(vmo, 2)..becomeName('abc');
      compare(vmo, 32,
          '${hexChar(BlockType.nameUtf8.value)} 1 03 0000 0000 0000 61 62 63');
      expect(
          Uint8List.view(
              block.nameUtf8.buffer, 0, block.nameUtf8.lengthInBytes),
          Uint8List.fromList([0x61, 0x62, 0x63]));
    });

    test('Becoming and setting an extent', () {
      final vmo = FakeVmo(64);
      final block = Block.create(vmo, 2)
        ..becomeFree(4)
        ..becomeReserved()
        ..becomeExtent(0x42)
        ..setExtentPayload(toByteData('abc'));
      compare(vmo, 32,
          '${hexChar(BlockType.extent.value)} 1 42 0000 0000 0000 61 62 63');
      expect(block.nextExtent, 0x42);
      expect(block.payloadSpaceBytes, block.size - headerSizeBytes);
    });
  });
}

/// Verify which block types are accepted by which functions.
///
/// For all block types (including anyValue), creates a block of that type and
///  passes it to [testFunction].
/// [previousStates] contains the types that should not throw
/// an error. All others should throw.
void _accepts(String testName, List<BlockType> previousStates, testFunction) {
  final vmo = FakeVmo(4096);
  for (BlockType type in BlockType.values) {
    final block = Block.createWithType(vmo, 0, type);
    if (previousStates.contains(type)) {
      expect(() => testFunction(block), returnsNormally,
          reason: '$testName should have accepted type $type');
    } else {
      expect(() => testFunction(block), throwsA(anything),
          reason: '$testName should not accept type $type');
    }
  }
}
