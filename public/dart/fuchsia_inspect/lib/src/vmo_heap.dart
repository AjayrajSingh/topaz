// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'vmo_holder.dart';

const int _blockSize = 32;

/// The base class for which log writers will inherit from.
///
/// (The current implementation is a barely-MVP heap: a 32-byte-block slab allocator.)
class VmoHeap extends VmoHolder {
  /// Size in bytes of the touched / visited subset of the VMO incorporated in the data structure.
  int _currentSize;

  /// Max size of the VMO in bytes.
  final int _maxSize;

  /// Offset of the first block on the freelist.
  int _freelistHead = 0;

  /// Construct with (initially touched size, maximum available size) of VMO.
  VmoHeap(this._currentSize, this._maxSize) : super(_maxSize) {
    _addFreelistBlocks(0, _currentSize);
  }

  void _addFreelistBlocks(int existingSize, int newSize) {
    // Placeholder code, not tested, certainly wrong.
    _freelistHead = existingSize;
    int i;
    for (i = existingSize; i < newSize - _blockSize; i += _blockSize) {
      writeInt64(i, i + _blockSize);
    }
    writeInt64(i, _freelistHead);
    _freelistHead = existingSize;
  }

  /// Maps more of the VMO.
  void growVmo(int desiredSize) {
    if (_currentSize == _maxSize) {
      return; // Fail silently.
    }
    int newSize = desiredSize;
    if (newSize > _maxSize) {
      newSize = _maxSize;
    }
    _addFreelistBlocks(_currentSize, newSize);
    _currentSize = newSize;
  }
}
