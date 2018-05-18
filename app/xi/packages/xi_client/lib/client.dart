// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

/// ignore_for_file: avoid_annotating_with_dynamic

/// A callback for data sent by xi-core.
///
/// TODO(jasoncampbell): Allow typed structures to be sent instead of strings.
typedef XiClientListener = void Function(dynamic data);

/// Callback for receiving result from a json-rpc request
typedef XiRpcCallback = void Function(dynamic data);

/// Handler, for handling requests (both notification and RPC) from core
abstract class XiRpcHandler {
  /// Handle a json-rpc notification
  void handleNotification(String method, dynamic params);

  /// Handle a json-rpc request. Note: the signature is currently
  /// synchronous (so that the handler must immediately return), but
  /// this may change. Not currently exercised.
  dynamic handleRpc(String method, dynamic params);
}

/// Generic abstract class for wrapping xi-core process/service
abstract class XiClient {
  /// Flag marking wether the client has been initialized or not.
  bool initialized = false;
  int _id = 0;
  final Map<int, XiRpcCallback> _pending = <int, XiRpcCallback>{};
  XiRpcHandler _handler;

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
        .transform(utf8.decoder)
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
  Future<Null> init();

  /// Register a handler. This causes incoming json-rpc requests to be
  /// routed to that handler.
  set handler(XiRpcHandler h) {
    _handler = h;
  }

  /// Register an event listener.
  void onMessage(XiClientListener callback) {
    listeners.add(callback);
  }

  /// Classes that extend [XiClient] should use this method to trigger any
  /// [listeners].
  void handleData(String data) {
    //print(data);
    Map<String, dynamic> decoded = json.decode(data);
    //TODO: plumb errors back through to caller
    if (decoded.containsKey('error')) {
      throw new UnimplementedError("xi client doesn't handle errors");
    }
    if (decoded.containsKey('result')) {
      int id = decoded['id'];
      XiRpcCallback callback = _pending.remove(id);
      if (callback != null) {
        callback(decoded['result']);
      } else {
        print('missing callback for id=$id');
      }
    } else if (_handler == null) {
      // not a response, so it must be a request
      print('no handler registered for request');
    } else {
      String method = decoded['method'];
      dynamic params = decoded['params'];
      if (decoded.containsKey('id')) {
        Map<String, dynamic> response = <String, dynamic>{
          'result': _handler.handleRpc(method, params),
          'id': decoded['id']
        };
        _sendJson(response);
      } else {
        _handler.handleNotification(method, params);
      }
    }
    if (listeners.isNotEmpty) {
      for (XiClientListener callback in listeners) {
        callback(decoded);
      }
    }
  }

  void _sendJson(dynamic decoded) {
    send(json.encode(decoded));
  }

  /// Send an asynchronous notification to the core.
  void sendNotification(String method, dynamic params) {
    Map<String, dynamic> json = <String, dynamic>{
      'method': method,
      'params': params
    };
    _sendJson(json);
  }

  /// Send an RPC request to the core. The callback will be invoked when there
  /// is a response.
  void sendRpc(String method, dynamic params, XiRpcCallback callback) {
    _pending[_id] = callback;
    Map<String, dynamic> json = <String, dynamic>{
      'method': method,
      'params': params,
      'id': _id
    };
    _sendJson(json);
    _id++;
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
