// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show utf8;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:zircon/zircon.dart';

const int _maxCombinedTags = 5;
const int _maxTagLength = 63;
const int _socketBufferLength = 2032;
const int _unexpectedLoggingLevel = 100;

const int _zxClockMonotonic = 0;
final Map<Level, int> _enumToFuchsiaLevelMap = <Level, int>{
  Level.FINEST: -4,
  Level.FINER: -3,
  Level.FINE: -2,
  Level.CONFIG: -1,
  Level.INFO: 0,
  Level.WARNING: 1,
  Level.SEVERE: 2,
  Level.SHOUT: 3,
};

/// A wrapper around [LogRecord] which appends additional data. This
/// is what is sent to the log writer when a record is received.
class LogMessage {
  /// The initial log record
  final LogRecord record;

  /// Any additional tags to append to the record.
  final List<String> tags;

  /// The id of the process which this log message is associated with
  final int processId;

  /// The id of the thread which this log message is associated with
  final int threadId;

  /// The time that this message was created
  final int systemTime = Platform.isFuchsia
      ? System.clockGet(_zxClockMonotonic)
      : new DateTime.now().microsecondsSinceEpoch * 1000;

  /// The stack trace at the call site. This is not to be confused with
  /// the stack trace in the [record] which is a stack trace that is being
  /// logged. This variable is used to later extract the code location
  /// to include in the message.
  final StackTrace callSiteTrace;

  /// The default constructor
  LogMessage({
    @required this.record,
    @required this.processId,
    @required this.threadId,
    this.tags = const [],
    this.callSiteTrace,
  })  : assert(record != null),
        assert(processId != null),
        assert(threadId != null);

  /// Converts this to a ByteData which can be used to send the message to the
  /// log socket.
  ByteData toBytes() {
    ByteData bytes = ByteData(_socketBufferLength)
      ..setUint64(0, processId, Endian.little)
      ..setUint64(8, threadId, Endian.little)
      ..setUint64(16, systemTime, Endian.little)
      ..setInt32(24, _convertLogLevel(record.level), Endian.little)
      ..setUint32(28, 0, Endian.little); // TODO(120860552) droppedLogs
    int byteOffset = 32;

    // Write global tags
    int totalTagCount = 0;
    for (final tag in tags) {
      if (tag != null && totalTagCount < _maxCombinedTags) {
        byteOffset = _setTag(bytes, byteOffset, tag);
        totalTagCount++;
      }
    }

    // We need to skip the local tags section since we do not support them
    bytes.setUint8(byteOffset++, 0);

    // Write message
    byteOffset = _setString(bytes, byteOffset, record.message,
        _socketBufferLength - byteOffset - 1);
    if (record.error != null) {
      byteOffset = _setString(
          bytes, byteOffset, ': ', _socketBufferLength - byteOffset - 1);
      byteOffset = _setString(bytes, byteOffset, record.error.toString(),
          _socketBufferLength - byteOffset - 1);
    }
    if (record.stackTrace != null) {
      byteOffset = _setString(
          bytes, byteOffset, '\n', _socketBufferLength - byteOffset - 1);
      byteOffset = _setString(bytes, byteOffset, record.stackTrace.toString(),
          _socketBufferLength - byteOffset - 1);
    }
    bytes.setUint8(byteOffset++, 0);
    return bytes.buffer.asByteData(0, byteOffset);
  }

  int _convertLogLevel(Level logLevel) =>
      _enumToFuchsiaLevelMap[logLevel] ?? _unexpectedLoggingLevel;

  /// Write a string to ByteData with a leading length byte. Return the
  /// byteOffstet to use for the next value. Wrie a non-terminated string to
  /// ByteData. Return the byteOffset to use for the terminating byte or the
  /// next value.
  int _setString(
      ByteData bytes, int firstByteOffset, String value, int maxLen) {
    if (value == null || value.isEmpty) {
      return firstByteOffset;
    }
    List<int> charBytes = utf8.encode(value);
    int len = min(charBytes.length, maxLen);
    int byteOffset = firstByteOffset;
    for (int i = 0; i < len; i++) {
      bytes.setUint8(byteOffset++, charBytes[i]);
    }
    // If the string was truncated (and there is space), add an elipsis character.
    if (len < charBytes.length && len >= 3) {
      const int period = 46; // UTF8 value for '.'
      for (int i = 1; i <= 3; i++) {
        bytes.setUint8(byteOffset - i, period);
      }
    }
    return byteOffset;
  }

  int _setTag(ByteData bytes, int byteOffset, String tag) {
    if (tag == null || tag == 'null') {
      return byteOffset;
    }
    int nextOffset = _setString(bytes, byteOffset + 1, tag, _maxTagLength);
    bytes.setUint8(byteOffset, nextOffset - byteOffset - 1);
    return nextOffset;
  }
}
