// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// The standard dart logger cannot be extended as the only way to create one is
// via factory methods. Those factory methods cannot return an instance of this
// class, which they know nothing about. To remedy that, this code provides a
// parallel implementation of Logger with extensions required to accommodate
// the extended functionality logger in fuchsia/zircon.
//
// This removes support for the hierarchical logger that is enabled in the dart
// version.

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:zircon/zircon.dart';

import 'fuchsia_log_record.dart';

/// Handler callback to process log entries as they are added to a [Logger].
typedef LoggerHandler = void Function(FuchsiaLogRecord logRecord);

const int _zxClockMonotonic = 0;

/// Use a [FuchsiaLogger] to log debug messages. This class adds fuchsia
/// specific extenstions for logging: time specified in zircon time and local
/// tags in log messages.
class FuchsiaLogger {
  /// Constructor
  FuchsiaLogger(this.level) {
    Logger.root.clearListeners();
    Logger.root.onRecord.listen((LogRecord rec) {
      log(rec.level, rec.message, /* local tag */ null, rec.error,
          rec.stackTrace);
    });
  }

  /// Logging [Level] used for entries generated on this logger.
  Level level;

  /// Controller used to notify when log entries are added to this logger.
  StreamController<FuchsiaLogRecord> _controller;

  /// Returns a stream of messages added to this [FuchsiaLogger].
  ///
  /// You can listen for messages using the standard stream APIs, for instance:
  ///
  /// ```dart
  /// logger.onRecord.listen((record) { ... });
  /// ```
  Stream<FuchsiaLogRecord> get onRecord => _getStream();

  /// Remove the Listener attached to this [FuchsiaLogger].
  void clearListener() {
    if (_controller != null) {
      _controller.close();
      _controller = null;
    }
  }

  /// Log message at level [Level.FINEST].
  // ignore: type_annotate_public_apis, always_specify_types
  void finest(message, [Object error, StackTrace stackTrace]) =>
      log(Level.FINEST, message, null, error, stackTrace);

  /// Log message at level [Level.FINER].
  // ignore: type_annotate_public_apis, always_specify_types
  void finer(message, [Object error, StackTrace stackTrace]) =>
      log(Level.FINER, message, null, error, stackTrace);

  /// Log message at level [Level.FINE].
  // ignore: type_annotate_public_apis, always_specify_types
  void fine(message, [Object error, StackTrace stackTrace]) =>
      log(Level.FINE, message, null, error, stackTrace);

  /// Log message at level [Level.CONFIG].
  // ignore: type_annotate_public_apis, always_specify_types
  void config(message, [Object error, StackTrace stackTrace]) =>
      log(Level.CONFIG, message, null, error, stackTrace);

  /// Log message at level [Level.INFO].
  // ignore: type_annotate_public_apis, always_specify_types
  void info(message, [Object error, StackTrace stackTrace]) =>
      log(Level.INFO, message, null, error, stackTrace);

  /// Log message at level [Level.WARNING].
  // ignore: type_annotate_public_apis, always_specify_types
  void warning(message, [Object error, StackTrace stackTrace]) =>
      log(Level.WARNING, message, null, error, stackTrace);

  /// Log message at level [Level.SEVERE].
  // ignore: type_annotate_public_apis, always_specify_types
  void severe(message, [Object error, StackTrace stackTrace]) =>
      log(Level.SEVERE, message, null, error, stackTrace);

  /// Log message at level [Level.SHOUT].
  // ignore: type_annotate_public_apis, always_specify_types
  void shout(message, [Object error, StackTrace stackTrace]) =>
      log(Level.SHOUT, message, null, error, stackTrace);

  /// Log message at level [Level.FINEST].
  // ignore: type_annotate_public_apis, always_specify_types
  void finestT(message, {String tag, Object error, StackTrace stackTrace}) =>
      log(Level.FINEST, message, tag, error, stackTrace);

  /// Log message at level [Level.FINER].
  // ignore: type_annotate_public_apis, always_specify_types
  void finerT(message, {String tag, Object error, StackTrace stackTrace}) =>
      log(Level.FINER, message, tag, error, stackTrace);

  /// Log message at level [Level.FINE].
  // ignore: type_annotate_public_apis, always_specify_types
  void fineT(message, {String tag, Object error, StackTrace stackTrace}) =>
      log(Level.FINE, message, tag, error, stackTrace);

  /// Log message at level [Level.CONFIG].
  // ignore: type_annotate_public_apis, always_specify_types
  void configT(message, {String tag, Object error, StackTrace stackTrace}) =>
      log(Level.CONFIG, message, tag, error, stackTrace);

  /// Log message at level [Level.INFO].
  // ignore: type_annotate_public_apis, always_specify_types
  void infoT(message, {String tag, Object error, StackTrace stackTrace}) =>
      log(Level.INFO, message, tag, error, stackTrace);

  /// Log message at level [Level.WARNING].
  // ignore: type_annotate_public_apis, always_specify_types
  void warningT(message, {String tag, Object error, StackTrace stackTrace}) =>
      log(Level.WARNING, message, tag, error, stackTrace);

  /// Log message at level [Level.SEVERE].
  // ignore: type_annotate_public_apis, always_specify_types
  void severeT(message, {String tag, Object error, StackTrace stackTrace}) =>
      log(Level.SEVERE, message, tag, error, stackTrace);

  /// Log message at level [Level.SHOUT].
  // ignore: type_annotate_public_apis, always_specify_types
  void shoutT(message, {String tag, Object error, StackTrace stackTrace}) =>
      log(Level.SHOUT, message, tag, error, stackTrace);

  /// Whether a message for [value]'s level is loggable in this logger.
  bool isLoggable(Level value) => value >= level;

  /// Adds a log record for a [message] at a particular [logLevel] if
  /// `isLoggable(logLevel)` is true.
  ///
  /// Use this method to create log entries for user-defined levels. To record a
  /// message at a predefined level (e.g. [Level.INFO], [Level.WARNING], etc)
  /// you can use their specialized methods instead (e.g. [info], [warning],
  /// etc).
  ///
  /// If [message] is a [Function], it will be lazy evaluated. Additionally, if
  /// [message] or its evaluated value is not a [String], then 'toString()' will
  /// be called on the object and the result will be logged. The log record will
  /// contain a field holding the original object.
  ///
  /// The log record will also contain a field for the zone in which this call
  /// was made. This can be advantageous if a log listener wants to handler
  /// records of different zones differently (e.g. group log records by HTTP
  /// request if each HTTP request handler runs in it's own zone).
  void log(Level logLevel, Object message, String localTag, Object error,
      StackTrace stackTrace) {
    if (!isLoggable(logLevel)) {
      return;
    }
    int systemTime = Platform.isFuchsia
        ? System.clockGet(_zxClockMonotonic)
        : new DateTime.now().microsecondsSinceEpoch * 1000;
    String logMsg;
    if (message is Function) {
      logMsg = message();
    } else if (message is String) {
      logMsg = message;
    } else {
      Object object = message;
      logMsg = object.toString();
    }
    _publish(new FuchsiaLogRecord(logLevel, logMsg, systemTime,
        localTag: localTag, error: error, stackTrace: stackTrace));
  }

  Stream<FuchsiaLogRecord> _getStream() {
    _controller ??=
        new StreamController<FuchsiaLogRecord>.broadcast(sync: true);
    return _controller.stream;
  }

  void _publish(FuchsiaLogRecord record) {
    if (_controller != null) {
      _controller.add(record);
    }
  }
}
