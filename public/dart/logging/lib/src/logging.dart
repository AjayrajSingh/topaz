// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:developer' show Timeline;
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:stack_trace/stack_trace.dart';

export 'package:logging/logging.dart';

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
void setupLogger({
  Logger logger,
  String name,
  Level level,
  bool forceShowCodeLocation,
}) {
  final String scopeName = name ??
      Platform.script?.pathSegments?.lastWhere((_) => true, orElse: () => null);

  // Use the root logger by default.
  logger ??= Logger.root;

  // Use the INFO level by default.
  logger.level = level ?? Level.INFO;

  logger.onRecord.listen((LogRecord rec) {
    final List<dynamic> scopes = <dynamic>[
      _getLevelString(rec.level),
    ];

    if (scopeName != null) {
      scopes.add(scopeName);
    }

    bool inCheckedMode = false;
    assert(() {
      inCheckedMode = true;
      return true;
    }());

    if (forceShowCodeLocation ?? inCheckedMode) {
      final Trace trace = new Trace.current();
      final Frame callerFrame = _findCallerFrame(trace);
      if (callerFrame != null) {
        if (callerFrame.uri.pathSegments.isNotEmpty) {
          final String filename = callerFrame.uri.pathSegments.last;
          final String line =
              callerFrame.line != null ? '(${callerFrame.line})' : '';
          scopes.add('$filename$line');
        }
      }
    }

    if (rec.error != null) {
      print('[${scopes.join(":")}] ${rec.message}: ${rec.error}');
    } else {
      print('[${scopes.join(":")}] ${rec.message}');
    }

    if (rec.stackTrace != null) {
      print('${rec.stackTrace}');
    }
  });

  _loggerName = scopeName;
  log = logger;
}

/// The default logger to be used by dart applications. Each application should
/// call [setupLogger()] in their main function to properly configure it.
Logger log = new Logger.detached('uninitialized')
  ..onRecord.listen((LogRecord rec) {
    print('WARNING: The logger is not initialized properly.');
    print('WARNING: Please call setupLogger() from your main function.');
    print('[${rec.level}] ${rec.message}');
  });

/// The name of the logger.
String _loggerName = 'uninitialized';

/// A convenient function for displaying the stack trace of the caller in the
/// console.
void showStackTrace() {
  final Trace trace = new Trace.current(1);
  print('$trace');
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

/// From the given [Trace], finds the first [Frame] after the `logging` package
/// and returns that frame. If no such [Frame] is found, returns `null`.
///
/// SEE: https://github.com/dart-lang/logging/issues/32
Frame _findCallerFrame(Trace trace) {
  bool foundLogging = false;

  for (int i = 0; i < trace.frames.length; ++i) {
    final Frame frame = trace.frames[i];

    final bool loggingPackage = frame.package == 'logging';
    if (foundLogging && !loggingPackage) {
      return frame;
    }

    foundLogging = loggingPackage;
  }

  return null;
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
