// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:zircon/zircon.dart';

// ignore_for_file: public_member_api_docs
// ignore_for_file: avoid_positional_boolean_parameters
// ignore_for_file: always_specify_types

const int _kAlignment = 8;
const int _kAlignmentMask = 0x7;
const int _kAllocAbsent = 0;
const int _kAllocPresent = 0xFFFFFFFFFFFFFFFF;
const int _kHandleAbsent = 0;
const int _kHandlePresent = 0xFFFFFFFF;

int _align(int size) =>
    size + ((_kAlignment - (size & _kAlignmentMask)) & _kAlignmentMask);

class FidlCodecError implements Exception {
  FidlCodecError(this.message);

  final String message;

  @override
  String toString() => message;
}

void _copyInt8(ByteData buffer, Int8List value, int offset) {
  final int count = value.length;
  for (int i = 0; i < count; ++i) {
    buffer.setInt8(offset + i, value[i]);
  }
}

void _copyUint8(ByteData buffer, Uint8List value, int offset) {
  final int count = value.length;
  for (int i = 0; i < count; ++i) {
    buffer.setUint8(offset + i, value[i]);
  }
}

void _copyInt16(ByteData buffer, Int16List value, int offset) {
  final int count = value.length;
  const int stride = 2;
  for (int i = 0; i < count; ++i) {
    buffer.setInt16(offset + i * stride, value[i], Endianness.LITTLE_ENDIAN);
  }
}

void _copyUint16(ByteData buffer, Uint16List value, int offset) {
  final int count = value.length;
  const int stride = 2;
  for (int i = 0; i < count; ++i) {
    buffer.setUint16(offset + i * stride, value[i], Endianness.LITTLE_ENDIAN);
  }
}

void _copyInt32(ByteData buffer, Int32List value, int offset) {
  final int count = value.length;
  const int stride = 4;
  for (int i = 0; i < count; ++i) {
    buffer.setInt32(offset + i * stride, value[i], Endianness.LITTLE_ENDIAN);
  }
}

void _copyUint32(ByteData buffer, Uint32List value, int offset) {
  final int count = value.length;
  const int stride = 4;
  for (int i = 0; i < count; ++i) {
    buffer.setUint32(offset + i * stride, value[i], Endianness.LITTLE_ENDIAN);
  }
}

void _copyInt64(ByteData buffer, Int64List value, int offset) {
  final int count = value.length;
  const int stride = 8;
  for (int i = 0; i < count; ++i) {
    buffer.setInt64(offset + i * stride, value[i], Endianness.LITTLE_ENDIAN);
  }
}

void _copyUint64(ByteData buffer, Uint64List value, int offset) {
  final int count = value.length;
  const int stride = 8;
  for (int i = 0; i < count; ++i) {
    buffer.setUint64(offset + i * stride, value[i], Endianness.LITTLE_ENDIAN);
  }
}

void _copyFloat32(ByteData buffer, Float32List value, int offset) {
  final int count = value.length;
  const int stride = 8;
  for (int i = 0; i < count; ++i) {
    buffer.setFloat32(offset + i * stride, value[i], Endianness.LITTLE_ENDIAN);
  }
}

void _copyFloat64(ByteData buffer, Float64List value, int offset) {
  final int count = value.length;
  const int stride = 8;
  for (int i = 0; i < count; ++i) {
    buffer.setFloat64(offset + i * stride, value[i], Endianness.LITTLE_ENDIAN);
  }
}

void _throwIfNotNullable(bool nullable) {
  if (!nullable) {
    throw new FidlCodecError('Cannot encode a null for a non-nullable type');
  }
}

void _throwIfNegative(int value) {
  if (value < 0) {
    throw new FidlCodecError(
        'Cannot encode a negative value for an unsigned type: $value');
  }
}

void _throwIfExceedsLimit(int count, int limit) {
  if (limit != null && count > limit) {
    throw new FidlCodecError(
        'Cannot encode an object wth $count elements. Limited to $limit.');
  }
}

void _throwIfCountMismatch(int count, int expectedCount) {
  if (count != expectedCount) {
    throw new FidlCodecError(
        'Cannot encode an array of count $count. Expected $expectedCount.');
  }
}

const Utf8Encoder _utf8Encoder = const Utf8Encoder();

Uint8List _convertToUTF8(String string) {
  return new Uint8List.fromList(_utf8Encoder.convert(string));
}

class _EncoderBuffer {
  _EncoderBuffer([int size = -1])
      : buffer = new ByteData(size > 0 ? size : kInitialBufferSize),
        handles = <Handle>[],
        extent = 0;

  ByteData buffer;
  final List<Handle> handles;
  int extent;

  static const int kInitialBufferSize = 1024;

  void _grow(int newSize) {
    Uint32List newBuffer = new Uint32List((newSize >> 2) + 1);
    int idx = 0;
    for (int i = 0; i < buffer.lengthInBytes; i += 4) {
      newBuffer[idx] = buffer.getUint32(i, Endianness.LITTLE_ENDIAN);
      idx++;
    }
    buffer = newBuffer.buffer.asByteData();
  }

  void claimMemory(int claimSize) {
    extent += claimSize;
    if (extent > buffer.lengthInBytes) {
      int newSize = buffer.lengthInBytes + claimSize;
      newSize += (newSize >> 1);
      _grow(newSize);
    }
  }

  ByteData get trimmed => new ByteData.view(buffer.buffer, 0, extent);
}

class Message {
  Message(this.buffer, this.handles, this.dataLength, this.handlesLength);
  Message.fromReadResult(ReadResult result)
      : buffer = result.bytes,
        handles = result.handles,
        dataLength = result.bytes.lengthInBytes,
        handlesLength = result.handles.length,
        assert(result.status == ZX.OK);

  final ByteData buffer;
  final List<Handle> handles;
  final int dataLength;
  final int handlesLength;

  void closeAllHandles() {
    if (handles != null) {
      for (int i = 0; i < handles.length; ++i) {
        handles[i].close();
      }
    }
  }

  @override
  String toString() =>
      'Message(numBytes=$dataLength, numHandles=$handlesLength)';
}

abstract class Encodable {
  int get encodedSize;

  void encode(Encoder encoder, int offset);
}

class Encoder {
  _EncoderBuffer _buffer;

  Encoder([int size = -1]) : _buffer = new _EncoderBuffer(size);

  Message get message {
    return new Message(_buffer.trimmed, _buffer.handles, _buffer.extent,
        _buffer.handles.length);
  }

  int alloc(int size) {
    int offset = _buffer.extent;
    _buffer.claimMemory(_align(size));
    return offset;
  }

  void encodeBool(bool value, int offset) {
    _buffer.buffer.setInt8(offset, value ? 1 : 0);
  }

  void encodeInt8(int value, int offset) {
    _buffer.buffer.setInt8(offset, value);
  }

  void encodeUint8(int value, int offset) {
    _throwIfNegative(value);
    _buffer.buffer.setUint8(offset, value);
  }

  void encodeInt16(int value, int offset) {
    _buffer.buffer.setInt16(offset, value, Endianness.LITTLE_ENDIAN);
  }

  void encodeUint16(int value, int offset) {
    _throwIfNegative(value);
    _buffer.buffer.setUint16(offset, value, Endianness.LITTLE_ENDIAN);
  }

  void encodeInt32(int value, int offset) {
    _buffer.buffer.setInt32(offset, value, Endianness.LITTLE_ENDIAN);
  }

  void encodeUint32(int value, int offset) {
    _throwIfNegative(value);
    _buffer.buffer.setUint32(offset, value, Endianness.LITTLE_ENDIAN);
  }

  void encodeInt64(int value, int offset) {
    _buffer.buffer.setInt64(offset, value, Endianness.LITTLE_ENDIAN);
  }

  void encodeUint64(int value, int offset) {
    _throwIfNegative(value);
    _buffer.buffer.setUint64(offset, value, Endianness.LITTLE_ENDIAN);
  }

  void encodeFloat32(double value, int offset) =>
      _buffer.buffer.setFloat32(offset, value, Endianness.LITTLE_ENDIAN);

  void encodeFloat64(double value, int offset) =>
      _buffer.buffer.setFloat64(offset, value, Endianness.LITTLE_ENDIAN);

  void encodeHandle(Handle value, int offset, bool nullable) {
    if (!value.isValid) {
      _throwIfNotNullable(nullable);
      encodeUint32(_kHandleAbsent, offset);
    } else {
      encodeUint32(_kHandlePresent, offset);
      _buffer.handles.add(value);
    }
  }

  void encodeStruct(Encodable value, int offset, bool nullable) {
    if (value == null) {
      _throwIfNotNullable(nullable);
      encodeUint64(_kAllocAbsent, offset);
    } else if (nullable) {
      encodeUint64(_kAllocPresent, offset);
      value.encode(this, alloc(value.encodedSize));
    } else {
      value.encode(this, offset);
    }
  }

  void encodeString(String value, int limit, int offset, bool nullable) {
    if (value == null) {
      _throwIfNotNullable(nullable);
      encodeUint64(0, offset); // size
      encodeUint64(_kAllocAbsent, offset); // data
      return null;
    }
    final Uint8List bytes = _convertToUTF8(value);
    final int size = bytes.lengthInBytes;
    _throwIfExceedsLimit(size, limit);
    encodeUint64(size, offset); // size
    encodeUint64(_kAllocPresent, offset); // data
    _copyUint8(_buffer.buffer, bytes, alloc(size));
  }

  // Encodes a fidl_vector_t.
  void _encodeVectorPointer(
      List<Object> value, int limit, int offset, bool nullable) {
    if (value == null) {
      _throwIfNotNullable(nullable);
      encodeUint64(0, offset); // count
      encodeUint64(_kAllocAbsent, offset); // data
      return;
    }
    final int count = value.length;
    _throwIfExceedsLimit(count, limit);
    encodeUint64(count, offset); // count
    encodeUint64(_kAllocPresent, offset); // data
  }

  void encodeEncodableVector(
      List<Encodable> value, int limit, int offset, bool nullable) {
    _encodeVectorPointer(value, limit, offset, nullable);
    if (value == null || value.isEmpty) {
      return;
    }
    // All members of a FIDL array have the same size.
    final int stride = _align(value[0].encodedSize);
    final int count = value.length;
    final int base = alloc(stride * count);
    for (int i = 0; i < count; ++i) {
      value[i].encode(this, base + i * stride);
    }
  }

  void encodeInt8ListAsVector(
      Int8List value, int limit, int offset, bool nullable) {
    _encodeVectorPointer(value, limit, offset, nullable);
    if (value == null || value.isEmpty) {
      return;
    }
    _copyInt8(_buffer.buffer, value, alloc(value.lengthInBytes));
  }

  void encodeUint8ListAsVector(
      Uint8List value, int limit, int offset, bool nullable) {
    _encodeVectorPointer(value, limit, offset, nullable);
    if (value == null || value.isEmpty) {
      return;
    }
    _copyUint8(_buffer.buffer, value, alloc(value.lengthInBytes));
  }

  void encodeInt16ListAsVector(
      Int16List value, int limit, int offset, bool nullable) {
    _encodeVectorPointer(value, limit, offset, nullable);
    if (value == null || value.isEmpty) {
      return;
    }
    _copyInt16(_buffer.buffer, value, alloc(value.lengthInBytes));
  }

  void encodeUint16ListAsVector(
      Uint16List value, int limit, int offset, bool nullable) {
    _encodeVectorPointer(value, limit, offset, nullable);
    if (value == null || value.isEmpty) {
      return;
    }
    _copyUint16(_buffer.buffer, value, alloc(value.lengthInBytes));
  }

  void encodeInt32ListAsVector(
      Int32List value, int limit, int offset, bool nullable) {
    _encodeVectorPointer(value, limit, offset, nullable);
    if (value == null || value.isEmpty) {
      return;
    }
    _copyInt32(_buffer.buffer, value, alloc(value.lengthInBytes));
  }

  void encodeUint32ListAsVector(
      Uint32List value, int limit, int offset, bool nullable) {
    _encodeVectorPointer(value, limit, offset, nullable);
    if (value == null || value.isEmpty) {
      return;
    }
    _copyUint32(_buffer.buffer, value, alloc(value.lengthInBytes));
  }

  void encodeInt64ListAsVector(
      Int64List value, int limit, int offset, bool nullable) {
    _encodeVectorPointer(value, limit, offset, nullable);
    if (value == null || value.isEmpty) {
      return;
    }
    _copyInt64(_buffer.buffer, value, alloc(value.lengthInBytes));
  }

  void encodeUint64ListAsVector(
      Uint64List value, int limit, int offset, bool nullable) {
    _encodeVectorPointer(value, limit, offset, nullable);
    if (value == null || value.isEmpty) {
      return;
    }
    _copyUint64(_buffer.buffer, value, alloc(value.lengthInBytes));
  }

  void encodeFloat32ListAsVector(
      Float32List value, int limit, int offset, bool nullable) {
    _encodeVectorPointer(value, limit, offset, nullable);
    if (value == null || value.isEmpty) {
      return;
    }
    _copyFloat32(_buffer.buffer, value, alloc(value.lengthInBytes));
  }

  void encodeFloat64ListAsVector(
      Float64List value, int limit, int offset, bool nullable) {
    _encodeVectorPointer(value, limit, offset, nullable);
    if (value == null || value.isEmpty) {
      return;
    }
    _copyFloat64(_buffer.buffer, value, alloc(value.lengthInBytes));
  }

  void encodeEncodableArray(List<Encodable> value, int count, int offset) {
    _throwIfCountMismatch(value.length, count);
    final int stride = _align(value[0].encodedSize);
    for (int i = 0; i < count; ++i) {
      value[i].encode(this, offset + i * stride);
    }
  }

  void encodeInt8ListAsArray(Int8List value, int count, int offset) {
    _throwIfCountMismatch(value.length, count);
    _copyInt8(_buffer.buffer, value, offset);
  }

  void encodeUint8ListAsArray(Uint8List value, int count, int offset) {
    _throwIfCountMismatch(value.length, count);
    _copyUint8(_buffer.buffer, value, alloc(value.lengthInBytes));
  }

  void encodeInt16ListAsArray(Int16List value, int count, int offset) {
    _throwIfCountMismatch(value.length, count);
    _copyInt16(_buffer.buffer, value, alloc(value.lengthInBytes));
  }

  void encodeUint16ListAsArray(Uint16List value, int count, int offset) {
    _throwIfCountMismatch(value.length, count);
    _copyUint16(_buffer.buffer, value, alloc(value.lengthInBytes));
  }

  void encodeInt32ListAsArray(Int32List value, int count, int offset) {
    _throwIfCountMismatch(value.length, count);
    _copyInt32(_buffer.buffer, value, alloc(value.lengthInBytes));
  }

  void encodeUint3ListAsArray(Uint32List value, int count, int offset) {
    _throwIfCountMismatch(value.length, count);
    _copyUint32(_buffer.buffer, value, alloc(value.lengthInBytes));
  }

  void encodeInt64ListAsArray(Int64List value, int count, int offset) {
    _throwIfCountMismatch(value.length, count);
    _copyInt64(_buffer.buffer, value, alloc(value.lengthInBytes));
  }

  void encodeUint64ListAsArray(Uint64List value, int count, int offset) {
    _throwIfCountMismatch(value.length, count);
    _copyUint64(_buffer.buffer, value, alloc(value.lengthInBytes));
  }

  void encodeFloat32ListAsArray(Float32List value, int count, int offset) {
    _throwIfCountMismatch(value.length, count);
    _copyFloat32(_buffer.buffer, value, alloc(value.lengthInBytes));
  }

  void encodeFloat64ListAsArray(Float64List value, int count, int offset) {
    _throwIfCountMismatch(value.length, count);
    _copyFloat64(_buffer.buffer, value, alloc(value.lengthInBytes));
  }
}
