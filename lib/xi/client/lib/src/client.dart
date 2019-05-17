// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:fuchsia_logger/logger.dart';

/// ignore_for_file: avoid_annotating_with_dynamic

/// A callback for data sent by xi-core.
///
/// TODO(jasoncampbell): Allow typed structures to be sent instead of strings.
typedef XiClientListener = void Function(dynamic data);

/// An error received from core in response to an RPC.
class CoreError {
  int code;
  String message;
  dynamic data;

  CoreError(Map<String, dynamic> errorJson) {
    code = errorJson['code'];
    message = errorJson['message'];
    data = errorJson['data'];
  }
}

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
  final Map<int, Completer<dynamic>> _pending = <int, Completer<dynamic>>{};
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
      StreamController<List<int>>();

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
    Map<String, dynamic> decoded = json.decode(data);
    if (decoded.containsKey('error')) {
      handleErrorResponse(decoded);
    } else if (decoded.containsKey('result')) {
      handleResponse(decoded);
    } else if (_handler == null) {
      // not a response, so it must be a request
      log.warning('no handler registered for request');
    } else {
      String method = decoded['method'];
      dynamic params = decoded['params'];
      // a request with an id must get a response
      if (decoded.containsKey('id')) {
        _handler.handleRpc(method, params).then((dynamic result) {
          sendResponse(decoded['id'], result);
        }).catchError((err) {
          sendErrorResponse(decoded['id'], err);
        });
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

  void handleErrorResponse(Map<String, dynamic> error) {
    log.warning('Received error response', error);
    int id = error['id'];
    Completer<dynamic> completer = _pending.remove(id);
    CoreError coreError = CoreError(error['error']);
    if (completer != null) {
      completer.completeError(coreError);
    }
  }

  void handleResponse(Map<String, dynamic> response) {
    int id = response['id'];
    Completer<dynamic> completer = _pending.remove(id);
    if (completer != null) {
      completer.complete(response['result']);
    }
  }

  void sendResponse(int id, dynamic payload) {
    Map<String, dynamic> response = <String, dynamic>{
      'result': payload,
      'id': id,
    };
    _sendJson(response);
  }

  void sendErrorResponse(int id, dynamic payload) {
    //TODO: have some real type for errors originating in the client
    Map<String, dynamic> error = <String, dynamic>{
      'code': 1,
      'msg': '$payload',
    };
    Map<String, dynamic> response = <String, dynamic>{
      'error': error,
      'id': id,
    };
    _sendJson(response);
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

  /// Send an RPC request to the core.
  Future<dynamic> sendRpc(String method, dynamic params) {
    Completer<dynamic> completer = Completer<dynamic>();
    _pending[_id] = completer;
    Map<String, dynamic> json = <String, dynamic>{
      'method': method,
      'params': params,
      'id': _id
    };
    _sendJson(json);
    _id++;
    return completer.future;
  }

  /// Generic error handler that can be used or everyone by implementations of [XiClient].
  void onError(Object error, StackTrace stackTrace) {
    log.severe('[XiClient ERROR]:', error, stackTrace);
    streamController.close();
  }
}
