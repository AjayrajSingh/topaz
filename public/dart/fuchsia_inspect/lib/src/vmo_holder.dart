// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';
import 'package:zircon/zircon.dart';

/// Holder for a VMO with read/write capability.
class VmoHolder {
  int _size;
  Vmo _vmo;

  /// Creates and holds a VMO of desired size.
  VmoHolder(this._size) {
    HandleResult result = System.vmoCreate(_size);
    if (result.status != ZX.OK) {
      throw new ZxStatusException(
          result.status, getStringForStatus(result.status));
    }
    _vmo = Vmo(result.handle);
  }

  /// Writes data to VMO at offset (not index).
  void write(int offset, ByteData data) {
    int status = _vmo.write(data, offset);
    if (status != ZX.OK) {
      throw new ZxStatusException(status, getStringForStatus(status));
    }
  }

  /// Reads data from VMO at offset (not index).
  ByteData read(int offset, int size) {
    ReadResult result = _vmo.read(size, offset);
    if (result.status != ZX.OK) {
      throw new ZxStatusException(
          result.status, getStringForStatus(result.status));
    }
    return result.bytes;
  }

  /// Writes int64 to VMO.
  void writeInt64(int offset, int value) {
    var data = ByteData(8)..setInt64(0, value, Endian.little);
    write(offset, data);
  }

  /// Reads int64 from VMO.
  int readInt64(int offset) {
    ByteData data = read(8, offset);
    return data.getInt64(0, Endian.little);
  }
}
