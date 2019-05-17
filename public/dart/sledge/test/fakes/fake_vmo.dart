// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';
import 'dart:typed_data';

import 'package:zircon/zircon.dart';

class FakeVmo extends Vmo {
  final Uint8List _data;
  FakeVmo(this._data) : super(null);

  @override
  GetSizeResult getSize() {
    if (_data == null) {
      return super.getSize();
    }
    return GetSizeResult(ZX.OK, _data.length);
  }

  @override
  ReadResult read(int numBytes, [int vmoOffset = 0]) {
    final ByteBuffer buffer = _data.buffer;
    int offsetInBytes = _data.offsetInBytes + vmoOffset;
    int len = min(numBytes, _data.length - offsetInBytes);
    if (len < 0) {
      // TODO: return fail status
    }
    if (len < numBytes) {
      // TODO: decide on returning status
    }
    return ReadResult(
        ZX.OK, buffer.asByteData(offsetInBytes, len), len, null);
  }
}
