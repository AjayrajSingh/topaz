// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of zircon_fakes;

// ignore_for_file: public_member_api_docs

/// An exception representing an error returned as an zx_status_t.
class ZxStatusException extends Error {
  final int status;
  ZxStatusException(this.status);
}

class _Result {
  final int status;
  const _Result(this.status);

  /// Throw an |ZxStatusException| if the |status| is not |ZX_OK|.
  void checkStatus() {
    if (status != 0) {
      throw new ZxStatusException(status);
    }
  }
}

class HandleResult extends _Result {
  final Handle handle;
  const HandleResult(final int status, [this.handle]) : super(status);
  @override
  String toString() => 'HandleResult(status=$status, handle=$handle)';
}

class HandlePairResult extends _Result {
  final Handle first;
  final Handle second;
  const HandlePairResult(final int status, [this.first, this.second])
      : super(status);
  @override
  String toString() =>
      'HandlePairResult(status=$status, first=$first, second=$second)';
}

class ReadResult extends _Result {
  final ByteData bytes;
  final int numBytes;
  final List<Handle> handles;
  const ReadResult(final int status, [this.bytes, this.numBytes, this.handles])
      : super(status);
  Uint8List bytesAsUint8List() =>
      bytes.buffer.asUint8List(bytes.offsetInBytes, numBytes);
  String bytesAsUTF8String() => UTF8.decode(bytesAsUint8List());
  @override
  String toString() =>
      'ReadResult(status=$status, bytes=$bytes, numBytes=$numBytes, handles=$handles)';
}

class WriteResult extends _Result {
  final int numBytes;
  const WriteResult(final int status, [this.numBytes]) : super(status);
  @override
  String toString() => 'WriteResult(status=$status, numBytes=$numBytes)';
}

class GetSizeResult extends _Result {
  final int size;
  const GetSizeResult(final int status, [this.size]) : super(status);
  @override
  String toString() => 'GetSizeResult(status=$status, size=$size)';
}

class System {
  // No public constructor - this only has static methods.
  System._();

  // Channel operations.
  static HandlePairResult channelCreate([int options = 0]) {
    throw new UnimplementedError(
        'Handle.channelCreate() is not implemented on this platform.');
  }
  static int channelWrite(Handle channel, ByteData data, List<Handle> handles) {
    throw new UnimplementedError(
        'Handle.channelWrite() is not implemented on this platform.');
  }
  static ReadResult channelQueryAndRead(Handle channel) {
    throw new UnimplementedError(
        'Handle.channelQueryAndRead() is not implemented on this platform.');
  }

  // Eventpair operations.
  static HandlePairResult eventpairCreate([int options = 0]) {
    throw new UnimplementedError(
        'Handle.eventpairCreate() is not implemented on this platform.');
  }

  // Socket operations.
  static HandlePairResult socketCreate([int options = 0]) {
    throw new UnimplementedError(
        'Handle.socketCreate() is not implemented on this platform.');
  }
  static WriteResult socketWrite(Handle socket, ByteData data, int options) {
    throw new UnimplementedError(
        'Handle.socketWrite() is not implemented on this platform.');
  }
  static ReadResult socketRead(Handle socket, int size) {
    throw new UnimplementedError(
        'Handle.socketRead() is not implemented on this platform.');
  }

  // Vmo operations.
  static HandleResult vmoCreate(int size, [int options = 0]) {
    throw new UnimplementedError(
        'Handle.vmoCreate() is not implemented on this platform.');
  }
  static GetSizeResult vmoGetSize(Handle vmo) {
    throw new UnimplementedError(
        'Handle.vmoGetSize() is not implemented on this platform.');
  }
  static int vmoSetSize(Handle vmo, int size) {
    throw new UnimplementedError(
        'Handle.vmoSetSize() is not implemented on this platform.');
  }
  static WriteResult vmoWrite(Handle vmo, int offset, ByteData bytes) {
    throw new UnimplementedError(
        'Handle.vmoWrite() is not implemented on this platform.');
  }
  static ReadResult vmoRead(Handle vmo, int offset, int size) {
    throw new UnimplementedError(
        'Handle.vmoRead() is not implemented on this platform.');
  }

  // Time operations.
  static int clockGet(int clockId) {
    throw new UnimplementedError(
        'Handle.timeGet() is not implemented on this platform.');
  }
}
