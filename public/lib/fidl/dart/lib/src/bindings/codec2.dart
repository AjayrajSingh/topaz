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

void _copyInt8(ByteData data, Int8List value, int offset) {
  final int count = value.length;
  for (int i = 0; i < count; ++i) {
    data.setInt8(offset + i, value[i]);
  }
}

void _copyUint8(ByteData data, Uint8List value, int offset) {
  final int count = value.length;
  for (int i = 0; i < count; ++i) {
    data.setUint8(offset + i, value[i]);
  }
}

void _copyInt16(ByteData data, Int16List value, int offset) {
  final int count = value.length;
  const int stride = 2;
  for (int i = 0; i < count; ++i) {
    data.setInt16(offset + i * stride, value[i], Endianness.LITTLE_ENDIAN);
  }
}

void _copyUint16(ByteData data, Uint16List value, int offset) {
  final int count = value.length;
  const int stride = 2;
  for (int i = 0; i < count; ++i) {
    data.setUint16(offset + i * stride, value[i], Endianness.LITTLE_ENDIAN);
  }
}

void _copyInt32(ByteData data, Int32List value, int offset) {
  final int count = value.length;
  const int stride = 4;
  for (int i = 0; i < count; ++i) {
    data.setInt32(offset + i * stride, value[i], Endianness.LITTLE_ENDIAN);
  }
}

void _copyUint32(ByteData data, Uint32List value, int offset) {
  final int count = value.length;
  const int stride = 4;
  for (int i = 0; i < count; ++i) {
    data.setUint32(offset + i * stride, value[i], Endianness.LITTLE_ENDIAN);
  }
}

void _copyInt64(ByteData data, Int64List value, int offset) {
  final int count = value.length;
  const int stride = 8;
  for (int i = 0; i < count; ++i) {
    data.setInt64(offset + i * stride, value[i], Endianness.LITTLE_ENDIAN);
  }
}

void _copyUint64(ByteData data, Uint64List value, int offset) {
  final int count = value.length;
  const int stride = 8;
  for (int i = 0; i < count; ++i) {
    data.setUint64(offset + i * stride, value[i], Endianness.LITTLE_ENDIAN);
  }
}

void _copyFloat32(ByteData data, Float32List value, int offset) {
  final int count = value.length;
  const int stride = 8;
  for (int i = 0; i < count; ++i) {
    data.setFloat32(offset + i * stride, value[i], Endianness.LITTLE_ENDIAN);
  }
}

void _copyFloat64(ByteData data, Float64List value, int offset) {
  final int count = value.length;
  const int stride = 8;
  for (int i = 0; i < count; ++i) {
    data.setFloat64(offset + i * stride, value[i], Endianness.LITTLE_ENDIAN);
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

void _throwIfNotZero(int value) {
  if (value != 0) {
    throw new FidlCodecError('Expected zero, got: $value');
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
const Utf8Decoder _utf8Decoder = const Utf8Decoder();

Uint8List _convertToUTF8(String string) {
  return new Uint8List.fromList(_utf8Encoder.convert(string));
}

String _convertFromUTF8(Uint8List bytes) {
  return _utf8Decoder.convert(bytes);
}

class _EncoderBuffer {
  _EncoderBuffer([int size = -1])
      : data = new ByteData(size > 0 ? size : kInitialBufferSize),
        handles = <Handle>[],
        extent = 0;

  ByteData data;
  final List<Handle> handles;
  int extent;

  static const int kInitialBufferSize = 1024;

  void _grow(int newSize) {
    final Uint8List newList = new Uint8List(newSize)
      ..setRange(0, data.lengthInBytes, data.buffer.asUint8List());
    data = newList.buffer.asByteData();
  }

  void claimMemory(int claimSize) {
    extent += claimSize;
    if (extent > data.lengthInBytes) {
      int newSize = data.lengthInBytes + claimSize;
      newSize += (newSize >> 1);
      _grow(newSize);
    }
  }

  ByteData get trimmed => new ByteData.view(data.buffer, 0, extent);
}

class Message {
  Message(this.data, this.handles, this.dataLength, this.handlesLength);
  Message.fromReadResult(ReadResult result)
      : data = result.bytes,
        handles = result.handles,
        dataLength = result.bytes.lengthInBytes,
        handlesLength = result.handles.length,
        assert(result.status == ZX.OK);

  final ByteData data;
  final List<Handle> handles;
  final int dataLength;
  final int handlesLength;

  int get txid => data.getUint32(0);
  int get ordinal => data.getUint32(16);

  void closeHandles() {
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

// ignore: one_member_abstracts
abstract class Encodable {
  void $encode(Encoder encoder, int offset);
}

class Encoder {
  _EncoderBuffer _buffer;

  Encoder(int txid, int ordinal, {int size: -1})
      : _buffer = new _EncoderBuffer(size) {
    _encodeMessageHeader(txid, ordinal);
  }

  Message get message {
    return new Message(_buffer.trimmed, _buffer.handles, _buffer.extent,
        _buffer.handles.length);
  }

  int alloc(int size) {
    int offset = _buffer.extent;
    _buffer.claimMemory(_align(size));
    return offset;
  }

  void _encodeMessageHeader(int txid, int ordinal) {
    alloc(32);
    encodeUint32(txid, 0);
    // Offset 8 is reserved0, which is always zero.
    // Offset 16 is flags, which are currently always zero.
    encodeUint32(ordinal, 24);
  }

  void encodeBool(bool value, int offset) {
    _buffer.data.setInt8(offset, value ? 1 : 0);
  }

  void encodeInt8(int value, int offset) {
    _buffer.data.setInt8(offset, value);
  }

  void encodeUint8(int value, int offset) {
    _throwIfNegative(value);
    _buffer.data.setUint8(offset, value);
  }

  void encodeInt16(int value, int offset) {
    _buffer.data.setInt16(offset, value, Endianness.LITTLE_ENDIAN);
  }

  void encodeUint16(int value, int offset) {
    _throwIfNegative(value);
    _buffer.data.setUint16(offset, value, Endianness.LITTLE_ENDIAN);
  }

  void encodeInt32(int value, int offset) {
    _buffer.data.setInt32(offset, value, Endianness.LITTLE_ENDIAN);
  }

  void encodeUint32(int value, int offset) {
    _throwIfNegative(value);
    _buffer.data.setUint32(offset, value, Endianness.LITTLE_ENDIAN);
  }

  void encodeInt64(int value, int offset) {
    _buffer.data.setInt64(offset, value, Endianness.LITTLE_ENDIAN);
  }

  void encodeUint64(int value, int offset) {
    _throwIfNegative(value);
    _buffer.data.setUint64(offset, value, Endianness.LITTLE_ENDIAN);
  }

  void encodeFloat32(double value, int offset) {
    _buffer.data.setFloat32(offset, value, Endianness.LITTLE_ENDIAN);
  }

  void encodeFloat64(double value, int offset) {
    _buffer.data.setFloat64(offset, value, Endianness.LITTLE_ENDIAN);
  }

  void encodeHandle(Handle value, int offset, bool nullable) {
    if (!value.isValid) {
      _throwIfNotNullable(nullable);
      encodeUint32(_kHandleAbsent, offset);
    } else {
      encodeUint32(_kHandlePresent, offset);
      _buffer.handles.add(value);
    }
  }

  void encodeEncodable(
      Encodable value, int encodedSize, int offset, bool nullable) {
    if (value == null) {
      _throwIfNotNullable(nullable);
      encodeUint64(_kAllocAbsent, offset);
    } else if (nullable) {
      encodeUint64(_kAllocPresent, offset);
      value.$encode(this, alloc(encodedSize));
    } else {
      value.$encode(this, offset);
    }
  }

  void encodeString(String value, int limit, int offset, bool nullable) {
    if (value == null) {
      _throwIfNotNullable(nullable);
      encodeUint64(0, offset); // size
      encodeUint64(_kAllocAbsent, offset + 8); // data
      return null;
    }
    final Uint8List bytes = _convertToUTF8(value);
    final int size = bytes.lengthInBytes;
    _throwIfExceedsLimit(size, limit);
    encodeUint64(size, offset); // size
    encodeUint64(_kAllocPresent, offset + 8); // data
    _copyUint8(_buffer.data, bytes, alloc(size));
  }

  // Encodes a fidl_vector_t.
  void _encodeVectorPointer(
      List<Object> value, int limit, int offset, bool nullable) {
    if (value == null) {
      _throwIfNotNullable(nullable);
      encodeUint64(0, offset); // count
      encodeUint64(_kAllocAbsent, offset + 8); // data
      return;
    }
    final int count = value.length;
    _throwIfExceedsLimit(count, limit);
    encodeUint64(count, offset); // count
    encodeUint64(_kAllocPresent, offset + 8); // data
  }

  void encodeEncodableVector(List<Encodable> value, int encodedSize, int limit,
      int offset, bool nullable) {
    _encodeVectorPointer(value, limit, offset, nullable);
    if (value == null || value.isEmpty) {
      return;
    }
    final int stride = _align(encodedSize);
    final int count = value.length;
    final int base = alloc(stride * count);
    for (int i = 0; i < count; ++i) {
      value[i].$encode(this, base + i * stride);
    }
  }

  void encodeInt8ListAsVector(
      Int8List value, int limit, int offset, bool nullable) {
    _encodeVectorPointer(value, limit, offset, nullable);
    if (value == null || value.isEmpty) {
      return;
    }
    _copyInt8(_buffer.data, value, alloc(value.lengthInBytes));
  }

  void encodeUint8ListAsVector(
      Uint8List value, int limit, int offset, bool nullable) {
    _encodeVectorPointer(value, limit, offset, nullable);
    if (value == null || value.isEmpty) {
      return;
    }
    _copyUint8(_buffer.data, value, alloc(value.lengthInBytes));
  }

  void encodeInt16ListAsVector(
      Int16List value, int limit, int offset, bool nullable) {
    _encodeVectorPointer(value, limit, offset, nullable);
    if (value == null || value.isEmpty) {
      return;
    }
    _copyInt16(_buffer.data, value, alloc(value.lengthInBytes));
  }

  void encodeUint16ListAsVector(
      Uint16List value, int limit, int offset, bool nullable) {
    _encodeVectorPointer(value, limit, offset, nullable);
    if (value == null || value.isEmpty) {
      return;
    }
    _copyUint16(_buffer.data, value, alloc(value.lengthInBytes));
  }

  void encodeInt32ListAsVector(
      Int32List value, int limit, int offset, bool nullable) {
    _encodeVectorPointer(value, limit, offset, nullable);
    if (value == null || value.isEmpty) {
      return;
    }
    _copyInt32(_buffer.data, value, alloc(value.lengthInBytes));
  }

  void encodeUint32ListAsVector(
      Uint32List value, int limit, int offset, bool nullable) {
    _encodeVectorPointer(value, limit, offset, nullable);
    if (value == null || value.isEmpty) {
      return;
    }
    _copyUint32(_buffer.data, value, alloc(value.lengthInBytes));
  }

  void encodeInt64ListAsVector(
      Int64List value, int limit, int offset, bool nullable) {
    _encodeVectorPointer(value, limit, offset, nullable);
    if (value == null || value.isEmpty) {
      return;
    }
    _copyInt64(_buffer.data, value, alloc(value.lengthInBytes));
  }

  void encodeUint64ListAsVector(
      Uint64List value, int limit, int offset, bool nullable) {
    _encodeVectorPointer(value, limit, offset, nullable);
    if (value == null || value.isEmpty) {
      return;
    }
    _copyUint64(_buffer.data, value, alloc(value.lengthInBytes));
  }

  void encodeFloat32ListAsVector(
      Float32List value, int limit, int offset, bool nullable) {
    _encodeVectorPointer(value, limit, offset, nullable);
    if (value == null || value.isEmpty) {
      return;
    }
    _copyFloat32(_buffer.data, value, alloc(value.lengthInBytes));
  }

  void encodeFloat64ListAsVector(
      Float64List value, int limit, int offset, bool nullable) {
    _encodeVectorPointer(value, limit, offset, nullable);
    if (value == null || value.isEmpty) {
      return;
    }
    _copyFloat64(_buffer.data, value, alloc(value.lengthInBytes));
  }

  void encodeEncodableArray(
      List<Encodable> value, int encodedSize, int count, int offset) {
    _throwIfCountMismatch(value.length, count);
    final int stride = _align(encodedSize);
    for (int i = 0; i < count; ++i) {
      value[i].$encode(this, offset + i * stride);
    }
  }

  void encodeInt8ListAsArray(Int8List value, int count, int offset) {
    _throwIfCountMismatch(value.length, count);
    _copyInt8(_buffer.data, value, offset);
  }

  void encodeUint8ListAsArray(Uint8List value, int count, int offset) {
    _throwIfCountMismatch(value.length, count);
    _copyUint8(_buffer.data, value, alloc(value.lengthInBytes));
  }

  void encodeInt16ListAsArray(Int16List value, int count, int offset) {
    _throwIfCountMismatch(value.length, count);
    _copyInt16(_buffer.data, value, alloc(value.lengthInBytes));
  }

  void encodeUint16ListAsArray(Uint16List value, int count, int offset) {
    _throwIfCountMismatch(value.length, count);
    _copyUint16(_buffer.data, value, alloc(value.lengthInBytes));
  }

  void encodeInt32ListAsArray(Int32List value, int count, int offset) {
    _throwIfCountMismatch(value.length, count);
    _copyInt32(_buffer.data, value, alloc(value.lengthInBytes));
  }

  void encodeUint3ListAsArray(Uint32List value, int count, int offset) {
    _throwIfCountMismatch(value.length, count);
    _copyUint32(_buffer.data, value, alloc(value.lengthInBytes));
  }

  void encodeInt64ListAsArray(Int64List value, int count, int offset) {
    _throwIfCountMismatch(value.length, count);
    _copyInt64(_buffer.data, value, alloc(value.lengthInBytes));
  }

  void encodeUint64ListAsArray(Uint64List value, int count, int offset) {
    _throwIfCountMismatch(value.length, count);
    _copyUint64(_buffer.data, value, alloc(value.lengthInBytes));
  }

  void encodeFloat32ListAsArray(Float32List value, int count, int offset) {
    _throwIfCountMismatch(value.length, count);
    _copyFloat32(_buffer.data, value, alloc(value.lengthInBytes));
  }

  void encodeFloat64ListAsArray(Float64List value, int count, int offset) {
    _throwIfCountMismatch(value.length, count);
    _copyFloat64(_buffer.data, value, alloc(value.lengthInBytes));
  }
}

typedef T DecodeCallback<T>(Decoder decoder, int offset);
typedef dynamic DecodeArrayCallback(Decoder decoder, int count, int offset);

Int8List _decodeInt8List(Decoder decoder, int count, int offset) {
  return decoder._data.buffer.asInt8List(offset, count);
}

Uint8List _decodeUint8List(Decoder decoder, int count, int offset) {
  return decoder._data.buffer.asUint8List(offset, count);
}

Int16List _decodeInt16List(Decoder decoder, int count, int offset) {
  return decoder._data.buffer.asInt16List(offset, count);
}

Uint16List _decodeUint16List(Decoder decoder, int count, int offset) {
  return decoder._data.buffer.asUint16List(offset, count);
}

Int32List _decodeInt32List(Decoder decoder, int count, int offset) {
  return decoder._data.buffer.asInt32List(offset, count);
}

Uint32List _decodeUint32List(Decoder decoder, int count, int offset) {
  return decoder._data.buffer.asUint32List(offset, count);
}

Int64List _decodeInt64List(Decoder decoder, int count, int offset) {
  return decoder._data.buffer.asInt64List(offset, count);
}

Uint64List _decodeUint64List(Decoder decoder, int count, int offset) {
  return decoder._data.buffer.asUint64List(offset, count);
}

Float32List _decodeFloat32List(Decoder decoder, int count, int offset) {
  return decoder._data.buffer.asFloat32List(offset, count);
}

Float64List _decodeFloat64List(Decoder decoder, int count, int offset) {
  return decoder._data.buffer.asFloat64List(offset, count);
}

class Decoder {
  Decoder(Message message)
      : _message = message,
        _data = message.data;

  Message _message;
  ByteData _data;

  int _nextOffset = 0;
  int _nextHandle = 0;

  int claimMemory(int size) {
    final int result = _nextOffset;
    _nextOffset += _align(size);
    if (_nextOffset > _message.dataLength) {
      throw new FidlCodecError('Cannot access out of range memory');
    }
    return result;
  }

  Handle claimHandle() {
    if (_nextHandle >= _message.handlesLength) {
      throw new FidlCodecError('Cannot access out of range handle');
    }
    return _message.handles[_nextHandle++];
  }

  bool decodeBool(int offset) => _data.getInt8(offset) != 0 ? true : false;

  int decodeInt8(int offset) => _data.getInt8(offset);

  int decodeUint8(int offset) => _data.getUint8(offset);

  int decodeInt16(int offset) =>
      _data.getInt16(offset, Endianness.LITTLE_ENDIAN);

  int decodeUint16(int offset) =>
      _data.getUint16(offset, Endianness.LITTLE_ENDIAN);

  int decodeInt32(int offset) =>
      _data.getInt32(offset, Endianness.LITTLE_ENDIAN);

  int decodeUint32(int offset) =>
      _data.getUint32(offset, Endianness.LITTLE_ENDIAN);

  int decodeInt64(int offset) =>
      _data.getInt64(offset, Endianness.LITTLE_ENDIAN);

  int decodeUint64(int offset) =>
      _data.getUint64(offset, Endianness.LITTLE_ENDIAN);

  double decodeFloat32(int offset) =>
      _data.getFloat32(offset, Endianness.LITTLE_ENDIAN);

  double decodeFloat64(int offset) =>
      _data.getFloat64(offset, Endianness.LITTLE_ENDIAN);

  Handle decodeHandle(int offset) {
    final int encoded = decodeInt32(offset);
    if (encoded == _kHandleAbsent) {
      return new Handle.invalid();
    } else if (encoded == _kHandlePresent) {
      return claimHandle();
    } else {
      throw new FidlCodecError('Invalid handle encoding.');
    }
  }

  T decodeEncodable<T>(
      DecodeCallback<T> decode, int encodedSize, int offset, bool nullable) {
    if (!nullable) {
      return decode(this, offset);
    }
    final int data = decodeUint64(offset);
    if (data == _kAllocAbsent) {
      return null;
    } else if (data == _kAllocPresent) {
      return decode(this, claimMemory(encodedSize));
    } else {
      throw new FidlCodecError('Invalid struct encoding.');
    }
  }

  String decodeString(int limit, int offset, bool nullable) {
    final int size = decodeUint64(offset);
    final int data = decodeUint64(offset + 8);
    if (data == _kAllocAbsent) {
      _throwIfNotNullable(nullable);
      _throwIfNotZero(size);
      return null;
    } else if (data == _kAllocPresent) {
      _throwIfExceedsLimit(size, limit);
      final int offset = claimMemory(size);
      final Uint8List bytes = _data.buffer.asUint8List(offset, size);
      return _convertFromUTF8(bytes);
    } else {
      throw new FidlCodecError('Invalid string encoding.');
    }
  }

  dynamic _decodeVector(DecodeArrayCallback decode, int stride, int limit,
      int offset, bool nullable) {
    final int count = decodeUint64(offset);
    final int data = decodeUint64(offset + 8);
    if (data == _kAllocAbsent) {
      _throwIfNotNullable(nullable);
      _throwIfNotZero(count);
      return null;
    } else if (data == _kAllocPresent) {
      _throwIfExceedsLimit(count, limit);
      final int offset = claimMemory(count * stride);
      return decode(this, count, offset);
    } else {
      throw new FidlCodecError('Invalid vector encoding.');
    }
  }

  dynamic decodeEncodableVector(DecodeArrayCallback decode, int encodedSize,
      int limit, int offset, bool nullable) {
    return _decodeVector(decode, _align(encodedSize), limit, offset, nullable);
  }

  Int8List decodeVectorAsInt8List(int limit, int offset, bool nullable) {
    return _decodeVector(_decodeInt8List, 1, limit, offset, nullable);
  }

  Uint8List decodeVectorAsUint8List(int limit, int offset, bool nullable) {
    return _decodeVector(_decodeUint8List, 1, limit, offset, nullable);
  }

  Int16List decodeVectorAsInt16List(int limit, int offset, bool nullable) {
    return _decodeVector(_decodeInt16List, 2, limit, offset, nullable);
  }

  Uint16List decodeVectorAsUint16List(int limit, int offset, bool nullable) {
    return _decodeVector(_decodeUint16List, 2, limit, offset, nullable);
  }

  Int32List decodeVectorAsInt32List(int limit, int offset, bool nullable) {
    return _decodeVector(_decodeInt32List, 4, limit, offset, nullable);
  }

  Uint32List decodeVectorAsUint32List(int limit, int offset, bool nullable) {
    return _decodeVector(_decodeUint32List, 4, limit, offset, nullable);
  }

  Int64List decodeVectorAsInt64List(int limit, int offset, bool nullable) {
    return _decodeVector(_decodeInt64List, 8, limit, offset, nullable);
  }

  Uint64List decodeVectorAsUint64List(int limit, int offset, bool nullable) {
    return _decodeVector(_decodeUint64List, 8, limit, offset, nullable);
  }

  Float32List decodeVectorAsFloat32List(int limit, int offset, bool nullable) {
    return _decodeVector(_decodeFloat32List, 4, limit, offset, nullable);
  }

  Float64List decodeVectorAsFloat64List(int limit, int offset, bool nullable) {
    return _decodeVector(_decodeFloat64List, 8, limit, offset, nullable);
  }

  Int8List decodeArrayAsInt8List(int count, int offset) {
    return _data.buffer.asInt8List(offset, count);
  }

  Uint8List decodeArrayAsUint8List(int count, int offset) {
    return _data.buffer.asUint8List(offset, count);
  }

  Int16List decodeArrayAsInt16List(int count, int offset) {
    return _data.buffer.asInt16List(offset, count);
  }

  Uint16List decodeArrayAsUint16List(int count, int offset) {
    return _data.buffer.asUint16List(offset, count);
  }

  Int32List decodeArrayAsInt32List(int count, int offset) {
    return _data.buffer.asInt32List(offset, count);
  }

  Uint32List decodeArrayAsUint32List(int count, int offset) {
    return _data.buffer.asUint32List(offset, count);
  }

  Int64List decodeArrayAsInt64List(int count, int offset) {
    return _data.buffer.asInt64List(offset, count);
  }

  Uint64List decodeArrayAsUint64List(int count, int offset) {
    return _data.buffer.asUint64List(offset, count);
  }

  Float32List decodeArrayAsFloat32List(int count, int offset) {
    return _data.buffer.asFloat32List(offset, count);
  }

  Float64List decodeArrayAsFloat64List(int count, int offset) {
    return _data.buffer.asFloat64List(offset, count);
  }
}
