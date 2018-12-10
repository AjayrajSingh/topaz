// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import '_log_message.dart';

const int _maxGlobalTags = 4; // leave one slot for code location
const int _maxTagLength = 63;

/// The base class for which log writers will inherit from. This class is
/// used to pipe logs from the onRecord stream
abstract class LogWriter {
  List<String> _globalTags = const [];

  StreamController<LogMessage> _controller;

  /// If set to true, this method will include the stack trace
  /// in each log record so we can later extract out the call site.
  /// This is a heavy operation and should be used with caution.
  bool forceShowCodeLocation = false;

  /// Constructor
  LogWriter({
    @required Logger logger,
    bool shouldBufferLogs = false,
  }) : assert(logger != null) {
    void Function(LogMessage) onMessageFunc;

    if (shouldBufferLogs) {
      // create single subscription stream controller so that we buffer calls to the
      // stream while we connect to the logger. This avoids dropping logs that
      // come in while we wait.
      _controller = StreamController<LogMessage>();

      onMessageFunc = _controller.add;
    } else {
      onMessageFunc = onMessage;
    }
    logger.onRecord.listen(
        (record) => onMessageFunc(_messageFromRecord(record)),
        onDone: () => _controller?.close());
  }

  /// The global tags to add to each log record.
  set globalTags(List<String> tags) => _globalTags = _verifyGlobalTags(tags);

  /// Remaps the level string to the ones used in FTL.
  String getLevelString(Level level) {
    if (level == null) {
      return null;
    }

    if (level == Level.FINE) {
      return 'VLOG(1)';
    } else if (level == Level.FINER) {
      return 'VLOG(2)';
    } else if (level == Level.FINEST) {
      return 'VLOG(3)';
    } else if (level == Level.SEVERE) {
      return 'ERROR';
    } else if (level == Level.SHOUT) {
      return 'FATAL';
    } else {
      return level.toString();
    }
  }

  LogMessage _messageFromRecord(LogRecord record) => LogMessage(
        record: record,
        processId: pid,
        threadId: Isolate.current.hashCode,
        tags: _globalTags,
        callSiteTrace: forceShowCodeLocation ? StackTrace.current : null,
      );

  /// A method for subclasses to implement to handle messages as they are
  /// written
  void onMessage(LogMessage message);

  /// A method which is exposed to subclasses which can be used to indicate that
  /// they are ready to start receiving messages.
  @protected
  void startListening(void Function(LogMessage) onMessage) =>
      _controller.stream.listen(onMessage);

  List<String> _verifyGlobalTags(List<String> tags) {
    List<String> result = <String>[];

    // make our own copy to allow us to remove null values an not change the
    // original values
    final incomingTags = List.of(tags)
      ..removeWhere((t) => t == null || t.isEmpty);

    if (incomingTags != null) {
      if (incomingTags.length > _maxGlobalTags) {
        Logger.root.warning('Logger initialized with > $_maxGlobalTags tags.');
        Logger.root.warning('Later tags will be ignored.');
      }
      for (int i = 0; i < _maxGlobalTags && i < incomingTags.length; i++) {
        String s = incomingTags[i];
        if (s.length > _maxTagLength) {
          Logger.root
              .warning('Logger tags limited to $_maxTagLength characters.');
          Logger.root.warning('Tag "$s" will be truncated.');
          s = s.substring(0, _maxTagLength);
        }
        result.add(s);
      }
    }
    return result;
  }

  //ignore: unused_element
  String _codeLocationFromStackTrace(StackTrace stackTrace) {
    // TODO(MS-2260) need to extract out the call site from the stack trace
    return '';
  }
}
