// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'vmo_holder.dart';

/// Types of VMO blocks.
enum BlockType {
  /// One block to rule them all. Index 0.
  header,

  /// Ready to be used.
  free,

  /// In transition toward being used.
  reserved,

  /// An entry in the Inspect tree, which may hold child Values: Nodes, Metrics, or Properties.
  node,

  /// An int Metric.
  intValue,

  /// A uint Metric.
  uintValue,

  /// A double Metric.
  doubleValue,

  /// A property that's been deleted but still has live children.
  tombstone,

  /// The header of a string (or byte-vector) Property.
  propertyValue,

  /// The contents of a string Property (in a singly linked list, if necessary).
  extent,

  /// The name of a Value (Property, Metric, or Node) (must be contained in this one block).
  name
}

/// Mirrors a single block in the VMO.
///
/// Can be read from VMO and/or modified by code, then written to VMO if desired.
class Block {
  /// Order: size = 2^(order+4); order is 1 in this slab allocator.
  int order = 1;

  /// The VMO-format-defined type of this block.
  BlockType type;

  /// Index of the block within the VMO.
  final int index;

  /// Reads the block at this index from the VMO.
  Block.read(VmoHolder vmo, this.index) {
    ByteData data = vmo.read(index * 16, 32);
    int header = data.getUint8(0);
    // TODO(cphoenix): Replace this with Bitfield64 and less-magic bit locations.
    type = BlockType.values[header & 0x0F];
    order = header >> 4;
    // TODO(cphoenix): Read the rest of the block, depending on type.
  }

  /// Size of the [Block] in bytes.
  int get size => 1 << (order + 4);
}
