// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:developer' show Timeline;
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:fidl_fuchsia_logger/fidl.dart' show LogSinkProxy;
import 'package:fidl_fuchsia_logger/fidl_async.dart' as logger_async
    show LogSinkProxy;
import 'package:lib.app.dart/app.dart' show connectToService, StartupContext;
import 'package:lib.app.dart/app_async.dart' as app_async
    show connectToService, StartupContext;
import 'package:logging/logging.dart' show Level;
import 'package:stack_trace/stack_trace.dart';
import 'package:zircon/zircon.dart' as zircon;

import 'fuchsia_log_record.dart';
import 'fuchsia_logger.dart';

const int _maxGlobalTags = 3;
const int _maxCombinedTags = 5;
const int _maxTagLength = 63;

const int _socketBufferLength = 2032;

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
const int _unexpectedLoggingLevel = 100;

/// Method to write a single log message to a single output medium.
/// Solutions are provided to write to stdout and a fuchsia Socket.
typedef LogWriter = void Function(LogWriterMessage message);

/// Interim method that sets up the logger using the new-style bindings for service resolution.
Future<void> setupLoggerAsync({
  String name,
  Level level,
  bool forceShowCodeLocation,
  bool logToStdoutForTest,
  List<String> globalTags,
  zircon.Socket logSocket,
  LogWriter logWriter,
}) async {
  zircon.Socket sock = logSocket;
  if (logSocket == null) {
    final socketPair = zircon.SocketPair(zircon.Socket.DATAGRAM);
    final logSinkProxy = new logger_async.LogSinkProxy();
    await app_async.connectToService(
      new app_async.StartupContext.fromStartupInfo().environmentServices,
      logSinkProxy.ctrl,
    );
    await logSinkProxy.connect(socketPair.second);
    sock = socketPair.first;
  }
  setupLogger(
      name: name,
      level: level,
      forceShowCodeLocation: forceShowCodeLocation,
      logToStdoutForTest: logToStdoutForTest,
      globalTags: globalTags,
      logSocket: sock,
      logWriter: logWriter);
}

/// Sets up the default logger for the current Dart application.
///
/// Every Dart application should call this [setupLogger] function in their main
/// before calling the actual log statements.
///
/// The provided [name] will be used for displaying the scope, and this name
/// will default to the last segment (i.e. basename) of the application url.
///
/// If [level] is provided, only the log messages of which level is greater than
/// equal to the provided [level] will be shown. If not provided, it defaults to
/// [Level.INFO].
///
/// By default, the caller code location is automatically added in checked mode
/// and not in production mode, because it is relatively expensive to calculate
/// the code location. If [forceShowCodeLocation] is set to true, the location
/// will be added in production mode as well.
///
/// If [globalTags] is provided, these tags will be added to each message logged
/// via this logger.
///
/// [logToStdoutForTest] will redirect log output to stdout. This should only be
/// used when debugging tests that run on device to mix the log output with
/// the messages from the test infrastructure. It has no effect for on-host
/// tests and should not be included in production code.
///
/// [logWriter] and [logSocket] are intended only for testing purposes.
void setupLogger({
  String name,
  Level level,
  bool forceShowCodeLocation,
  bool logToStdoutForTest,
  List<String> globalTags,
  zircon.Socket logSocket,
  LogWriter logWriter,
}) {
  final String scopeName = name ??
      Platform.script?.pathSegments?.lastWhere((_) => true, orElse: () => null);
  final List<String> approvedTags = _verifyGlobalTags(globalTags);

  log = new FuchsiaLogger(level ?? Level.INFO);

  // This code decides how to log messages. Here's the why:
  // If not running on zircon, there is no sys_logger so must use stdout.
  // The author can force stdout via flag to assist is debugging tests.
  // logSocket and logWriter are used for internal logging tests.
  LogWriter activeLogWriter;
  if (logWriter != null) {
    activeLogWriter = logWriter;
  } else if (logToStdoutForTest != true &&
      (Platform.isFuchsia || logSocket != null)) {
    _logSocket = logSocket ?? _connectToLoggerSocket();
    activeLogWriter = writeLogToSocket;
  } else {
    activeLogWriter = writeLogToStdout;
  }
  _loggerName = scopeName;

  bool inCheckedMode = false;
  assert(() {
    inCheckedMode = true;
    return true;
  }());

  log.onRecord.listen((FuchsiaLogRecord rec) {
    String codeLocation;
    if (forceShowCodeLocation ?? inCheckedMode) {
      final Trace trace = new Trace.current();
      final Frame callerFrame = _findCallerFrame(trace);
      if (callerFrame != null) {
        if (callerFrame.uri.pathSegments.isNotEmpty) {
          final String filename = callerFrame.uri.pathSegments.last;
          final String line =
              callerFrame.line != null ? '(${callerFrame.line})' : '';
          codeLocation = '$filename$line';
        }
      }
    }

    activeLogWriter(new LogWriterMessage(
      logRecord: rec,
      scopeName: scopeName,
      codeLocation: codeLocation,
      tags: approvedTags,
    ));
  });
}

/// Create a Socket and connect it to the FIDL logger
zircon.Socket _connectToLoggerSocket() {
  final socketPair = zircon.SocketPair(zircon.Socket.DATAGRAM);
  final logSinkProxy = new LogSinkProxy();
  connectToService(
    new StartupContext.fromStartupInfo().environmentServices,
    logSinkProxy.ctrl,
  );
  logSinkProxy.connect(socketPair.second);
  return socketPair.first;
}

/// All information required to construct a log message to either stdout or
/// Zircon logging Socket.
class LogWriterMessage {
  /// Log record created by fuchsiaLogger
  final FuchsiaLogRecord logRecord;

  /// Name from the logger, typically the module name
  final String scopeName;

  /// If specified, file name and line number where this log message originated
  final String codeLocation;

  /// Identifying tags to associate with this logging message
  final List<String> tags;

  /// Constructor
  LogWriterMessage(
      {this.logRecord, this.scopeName, this.codeLocation, this.tags});
}

/// The default logger to be used by dart applications. Each application should
/// call [setupLogger()] in their main function to properly configure it.
FuchsiaLogger log = new FuchsiaLogger(Level.ALL)
  ..onRecord.listen((FuchsiaLogRecord rec) {
    print('WARNING: The logger is not initialized properly.');
    print('WARNING: Please call setupLogger() from your main function.');
    print('[${rec.level}] ${rec.message}');
  });

/// The name of the logger.
String _loggerName = 'uninitialized';

/// Socket used to write to the universal Zircon logger.
zircon.Socket _logSocket;

// Enforce limits on number of global tags and length of each tag
List<String> _verifyGlobalTags(List<String> globalTags) {
  List<String> result = <String>[];
  if (globalTags != null) {
    if (globalTags.length > _maxGlobalTags) {
      print('WARNING: Logger initialized with > $_maxGlobalTags tags.');
      print('WARNING: Later tags will be ignored.');
    }
    for (int i = 0; i < _maxGlobalTags && i < globalTags.length; i++) {
      String s = globalTags[i];
      if (s.length > _maxTagLength) {
        print('WARNING: Logger tags limited to $_maxTagLength characters.');
        print('WARNING: Tag "$s" will be truncated.');
        s = s.substring(0, _maxTagLength);
      }
      result.add(s);
    }
  }
  return result;
}

/// LogWriter that outputs to stdout in a similar format the original fuchsia
///  logger.
void writeLogToStdout(LogWriterMessage message) {
  final List<dynamic> scopes = <dynamic>[
    _getLevelString(message.logRecord.level),
  ];
  if (message.scopeName != null) {
    scopes.add(message.scopeName);
  }
  if (message.codeLocation != null) {
    scopes.add(message.codeLocation);
  }
  message.tags.forEach(scopes.add);
  String scopesString = scopes.join(':');
  if (message.logRecord.error != null) {
    print(
        '[$scopesString] ${message.logRecord.message}: ${message.logRecord.error}');
  } else {
    print('[$scopesString] ${message.logRecord.message}');
  }

  if (message.logRecord.stackTrace != null) {
    print('${message.logRecord.stackTrace}');
  }
}

int _convertLogLevel(Level logLevel) =>
    _enumToFuchsiaLevelMap[logLevel] ?? _unexpectedLoggingLevel;

/// Format log message zircon socket connected to Log Viewer
void writeLogToSocket(LogWriterMessage message) {
  ByteData bytes = new ByteData(_socketBufferLength)
    ..setUint64(0, pid, Endian.little)
    ..setUint64(8, Isolate.current.hashCode, Endian.little)
    ..setUint64(16, message.logRecord.systemTime, Endian.little)
    ..setUint32(24, _convertLogLevel(message.logRecord.level), Endian.little)
    ..setUint32(28, 0, Endian.little); // TODO droppedLogs
  int byteOffset = 32;

  // Write global tags
  int totalTagCount = 0;
  if (message.scopeName != null) {
    byteOffset = _setTag(bytes, byteOffset, message.scopeName);
    totalTagCount++;
  }
  if (message.codeLocation != null) {
    byteOffset = _setTag(bytes, byteOffset, message.codeLocation);
    totalTagCount++;
  }
  for (String tag in message.tags) {
    if (tag != null && totalTagCount < _maxCombinedTags) {
      byteOffset = _setTag(bytes, byteOffset, tag);
      totalTagCount++;
    }
  }
  // Local tags are currently not supported by dart.
  bytes.setUint8(byteOffset++, 0);

  // Write message
  byteOffset = _setString(bytes, byteOffset, message.logRecord.message,
      _socketBufferLength - byteOffset - 1);
  if (message.logRecord.error != null) {
    byteOffset = _setString(
        bytes, byteOffset, ': ', _socketBufferLength - byteOffset - 1);
    byteOffset = _setString(
        bytes,
        byteOffset,
        message.logRecord.error.toString(),
        _socketBufferLength - byteOffset - 1);
  }
  if (message.logRecord.stackTrace != null) {
    byteOffset = _setString(
        bytes, byteOffset, '\n', _socketBufferLength - byteOffset - 1);
    byteOffset = _setString(
        bytes,
        byteOffset,
        message.logRecord.stackTrace.toString(),
        _socketBufferLength - byteOffset - 1);
  }
  bytes.setUint8(byteOffset++, 0);
  assert(byteOffset <= _socketBufferLength);
  _logSocket.write(new ByteData.view(bytes.buffer, 0, byteOffset));
}

// Write a string to ByteData with a leading length byte. Return the byteOffstet
// to use for the next value.
int _setTag(ByteData bytes, int byteOffset, String tag) {
  if (tag == null || tag == 'null') {
    return byteOffset;
  }
  int nextOffset = _setString(bytes, byteOffset + 1, tag, _maxTagLength);
  bytes.setUint8(byteOffset, nextOffset - byteOffset - 1);
  return nextOffset;
}

// Wrie a non-terminated string to ByteData. Return the byteOffset to use for
// the terminating byte or the next value.
int _setString(ByteData bytes, int firstByteOffset, String value, int maxLen) {
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

/// A convenient function for displaying the stack trace of the caller in the
/// console.
void showStackTrace() {
  print(new Trace.current(1).toString());
}

/// Whether a message for [value]'s level is tracable in this logger.
bool _isTraceable(Level value) => (value >= Level.INFO);

/// Emits an instant trace with [name] prefixed with [log]'s name if [log]'s
/// level is INFO or above.
void trace(String name) {
  if (_isTraceable(log.level)) {
    Timeline.instantSync('$_loggerName $name');
  }
}

/// From the given [Trace], finds the last [Frame] from this package
/// (lib.app.dart) and then the next [Frame] not in this package. That frame
/// represents whomever called the log function and is returned.
/// If no such [Frame] is found, returns `null`.
///
/// SEE: https://github.com/dart-lang/logging/issues/32
Frame _findCallerFrame(Trace trace) {
  bool foundLogging = false;
  Frame matchedFrame;

  for (int i = 0; i < trace.frames.length; ++i) {
    final Frame frame = trace.frames[i];
    final bool loggingPackage = frame.package == 'lib.app.dart';
    if (foundLogging && !loggingPackage) {
      matchedFrame = frame;
    }
    foundLogging = loggingPackage;
  }

  return matchedFrame;
}

/// Remaps the level string to the ones used in FTL.
String _getLevelString(Level level) {
  if (level == null) {
    return null;
  }

  if (level == Level.FINE) {
    return 'VLOG(1)';
  }

  if (level == Level.FINER) {
    return 'VLOG(2)';
  }

  if (level == Level.FINEST) {
    return 'VLOG(3)';
  }

  if (level == Level.SEVERE) {
    return 'ERROR';
  }

  if (level == Level.SHOUT) {
    return 'FATAL';
  }

  return level.toString();
}
