// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:logging/logging.dart' show Level;

/// A log entry representation used to propagate information from
/// FuchsiaLogger to individual handlers.
class FuchsiaLogRecord {
  /// Time specified in system time. On a system running zircon this is
  /// defined by zx_get_time() as nanoseconds since boot. Otherwise it is
  /// defined by DateTime.now().microsecondsSinceEpoch converted to nanoseconds.
  final int systemTime;

  /// One additional tag specified for this log record.
  final String localTag;

  /// Level of severity for this log message.
  final Level level;

  /// Message to display.
  final String message;

  /// Unique sequence number greater than all log records created before it.
  final int sequenceNumber;

  static int _nextNumber = 1;

  /// Associated error (if any) when recording errors messages.
  final Object error;

  /// Associated stackTrace (if any) when recording errors messages.
  final StackTrace stackTrace;

  /// Constructor
  FuchsiaLogRecord(this.level, this.message, this.systemTime,
      {this.localTag, this.error, this.stackTrace})
      : sequenceNumber = _nextNumber++;

  @override
  String toString() => '[${level.name}] $message';
}
