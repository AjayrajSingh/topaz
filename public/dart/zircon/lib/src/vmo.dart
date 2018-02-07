// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of zircon;

// ignore_for_file: public_member_api_docs

class Vmo extends _HandleWrapper<Vmo> {
  Vmo(Handle handle) : super(handle);

  GetSizeResult getSize() {
    if (handle == null) {
      return const GetSizeResult(ZX.ERR_INVALID_ARGS);
    }

    return System.vmoGetSize(handle);
  }

  int setSize(int size) {
    if (handle == null || size < 0) {
      return ZX.ERR_INVALID_ARGS;
    }

    return System.vmoSetSize(handle, size);
  }

  WriteResult write(ByteData data, [int vmoOffset = 0]) {
    if (handle == null) {
      return const WriteResult(ZX.ERR_INVALID_ARGS);
    }

    return System.vmoWrite(handle, vmoOffset, data);
  }

  ReadResult read(int numBytes, [int vmoOffset = 0]) {
    if (handle == null) {
      return const ReadResult(ZX.ERR_INVALID_ARGS);
    }

    return System.vmoRead(handle, vmoOffset, numBytes);
  }

  /// Maps the Vmo into the process's root vmar, and returns it as a typed data
  /// array.
  ///
  /// The returned [Uint8List] is read-only. Attempts to write to it will
  /// crash the process.
  // TODO(dartbug.com/32028): When read only typed-data arrays are added to the
  // Dart SDK, return one of those instead.
  Uint8List map() {
    if (handle == null) {
      final int status = ZX.ERR_INVALID_ARGS;
      throw new ZxStatusException(status, getStringForStatus(status));
    }
    MapResult r = System.vmoMap(handle);
    if (r.status != ZX.OK) {
      throw new ZxStatusException(r.status, getStringForStatus(r.status));
    }
    return r.data;
  }
}

class SizedVmo extends Vmo {
  final int _size;

  SizedVmo(Handle handle, this._size) : super(handle);

  /// Uses fdio_get_vmo() to get a VMO for the file at `path` in the current
  /// Isolate's namespace.
  ///
  /// The returned Vmo is read-only.
  factory SizedVmo.fromFile(String path) {
    FromFileResult r = System.vmoFromFile(path);
    if (r.status != ZX.OK) {
      throw new ZxStatusException(r.status, getStringForStatus(r.status));
    }
    return new SizedVmo(r.handle, r.numBytes);
  }

  /// Size of the Vmo in bytes.
  int get size => _size;
}
