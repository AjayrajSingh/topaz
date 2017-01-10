// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:async';

/// A callback for data sent by xi-core.
///
/// TODO(jasoncampbell): Allow typed structures to be sent instead of strings.
typedef void XiClientListener(String data);

/// Generic abstract class for wrapping xi-core process/service
abstract class XiClient {
  /// Flag marking wether the client has been initialized or not.
  bool initialized = false;

  /// Callbacks fired whenever a message from xi-core is received. Add with
  /// [onMessage].
  List<XiClientListener> listeners = <XiClientListener>[];

  /// A [StreamController] that handles the transformation of input from
  /// either the xi-core FIDL service or the xi-core process. To send data
  /// through the pipeline use the stream controller. For example, to connect
  /// to a Process' stdout:
  ///
  ///     process.stdout.listen(streamController.add);
  ///
  StreamController<List<int>> streamController =
      new StreamController<List<int>>();

  /// [XiClient] constructor.
  XiClient() {
    // Adds a transformation pipeline for stream input into line separated
    // strings.
    //
    // TODO(jasoncampbell): add a transformation for automatic JSON
    // deserialization.
    streamController.stream
        .transform(UTF8.decoder)
        .transform(const LineSplitter())
        .listen(
          handleData,
          onError: onError,
          cancelOnError: true,
        );
  }

  /// Override this method to control where/how messages are sent to the
  /// xi-core process or service.
  void send(String data);

  /// Override this method and add any required initialization work.
  void init();

  /// Register an event listener.
  void onMessage(XiClientListener callback) {
    listeners.add(callback);
  }

  /// Classes that extend [XiClient] should use this method to trigger any
  /// [listeners].
  void handleData(String data) {
    if (listeners.length > 0) {
      listeners.forEach((XiClientListener callback) => callback(data));
    }
  }

  /// Generic error handler that can be used or everyone by implementations of [XiClient].
  void onError(Error error) {
    print('[XiClient ERROR]: $error');
    if (error.stackTrace != null) {
      print(error.stackTrace);
    }

    streamController.close();
  }
}
