// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import '_log_message.dart';
import '_log_writer.dart';

/// A concrete implementation of [LogWriter] which prints the logs to stdout.
class StdoutLogWriter extends LogWriter {
  /// Constructor
  StdoutLogWriter({@required Logger logger})
      : assert(logger != null),
        super(
          logger: logger,
          shouldBufferLogs: false,
        );

  @override
  void onMessage(LogMessage message) {
    final scopes = [
      getLevelString(message.record.level),
    ];

    message.tags.forEach(scopes.add);
    String scopesString = scopes.join(':');

    if (message.record.error != null) {
      print(
          '[$scopesString] ${message.record.message}: ${message.record.error}');
    } else {
      print('[$scopesString] ${message.record.message}');
    }

    if (message.record.stackTrace != null) {
      print('${message.record.stackTrace}');
    }
  }
}
