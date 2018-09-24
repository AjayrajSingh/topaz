// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const int kConnectionAttempts = 3;
const Duration kConnectionRetryDelay = Duration(seconds: 2);

Future<WebSocket> _connect(String url,
    List<Exception> exceptions) async {
  if (exceptions.length == kConnectionAttempts) {
    throw exceptions.last;
  }

  if (exceptions.isNotEmpty) {
    stderr.writeln(exceptions.last.toString());
    stderr.writeln('Retrying...');
    sleep(kConnectionRetryDelay);
  }

  try {
    return await WebSocket.connect(url);
  } on SocketException catch(e) {
    exceptions.add(e);
    return _connect(url, exceptions);
  }
}

class RemoteVm {
  JsonEncoder toJson = JsonEncoder();
  JsonDecoder fromJson = JsonDecoder();

  WebSocket ws;
  String isolateId;

  /// We send a unique ID for each request, and the remote VM sends a response
  /// message with the same ID. We need a way to match them.
  ///
  /// The responses map is indexed by request ID. A completer is inserted when
  /// a request is sent, and it is completed when the response is received.
  Map<int, Completer<dynamic>> responses = {};
  int nextId = 0;

  Future<void> connect(String url) async {
    ws = await _connect(url, [])..listen(onResponse);

    var streamListenResponse = await request('streamListen',
        {'streamId': 'VM'});
    if (streamListenResponse['type'] != 'Success') {
      throw streamListenResponse;
    }

    var vmResponse = await request('getVM', {});
    isolateId = vmResponse['isolates'][0]['id'];
  }

  void onResponse(dynamic data) {
    var obj = fromJson.convert(data);
    responses[obj['id']].complete(obj['result']);
  }

  Future<dynamic> request(String method, dynamic params) {
    var id = nextId++;
    ws.add(toJson.convert({'id': id, 'method': method, 'params': params}));
    var completer = Completer();
    responses[id] = completer;
    return completer.future;
  }

  Future<dynamic> evaluate(String expression) {
    var params = {
      'isolateId': isolateId,
      'frameIndex': 0,
      'expression': expression,
    };
    return request('evaluateInFrame', params);
  }
}
