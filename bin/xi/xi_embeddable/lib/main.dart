// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fidl_fuchsia_xi_session/fidl_async.dart';
import 'package:fuchsia_logger/logger.dart';
import 'package:fuchsia_modular/module.dart';
import 'package:fuchsia_modular/service_connection.dart';
import 'package:xi_widgets/widgets.dart';
import 'package:xi_fuchsia_client/client.dart';
import 'package:zircon/zircon.dart';

/// If `true`, draws the editor with a watermarked background.
/// NOTE: This was added to make it easier to debug view loading when
/// working on view embedding.
const bool kDrawDebugBackground = true;

/// Identifier for the modular agent that manages xi sessions.
const String kSessionManagerURL = 'xi_session_agent';

void main() {
  setupLogger(name: 'xi_embeddable');
  log.info('Module main called');

  final handler = StreamingIntentHandler();
  Module().registerIntentHandler(handler);

  final sessionManager = XiSessionManagerProxy();
  connectToAgentService(kSessionManagerURL, sessionManager);

  SocketPair pair = SocketPair();
  final client = EmbeddedClient(pair.first)..init();

  handler.stream.first.then(_getSessionId).then((sessionId) {
    log.info('got [$sessionId]');
    // We pass the sessionId and one side of the socket to the agent.
    // We will then be able to communicate back and forth via `client`.
    return sessionManager.connectSession(sessionId, pair.second);
  }).then((_) {
    sessionManager.ctrl.close();
  }).catchError(
      (err, trace) => log.severe('failed to get link or agent', err, trace));

  runApp(EmbeddedEditor(
    client: client,
    debugBackground: kDrawDebugBackground,
  ));
}

Future<String> _getSessionId(Intent intent) async {
  //Note: this is currently broken and needs to be updated once the
  //module is launched via an intent
  final entity =
      intent.getEntity(name: 'session-id', type: 'com.fuchsia.xi.session-id');
  final data = await entity.getData();
  return utf8.decode(data);
}
