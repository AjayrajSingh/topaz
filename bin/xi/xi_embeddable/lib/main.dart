// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fidl_fuchsia_mem/fidl.dart' as fuchsia_mem;
import 'package:fidl_fuchsia_xi_session/fidl_async.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.app.dart/logging.dart';
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

  // TODO: Refactor this class to use the new SDK instead of deprecated API
  // ignore: deprecated_member_use
  final _driver = new ModuleDriver();
  XiSessionManager _sessionManager;

  SocketPair pair = SocketPair();
  final client = EmbeddedClient(pair.first)..init();

// To do anything, we need our initial link and a connection to the agent.
  Future
      .wait([_getLink(_driver), _getSessionManager(_driver)])
      .then((result) {
        String sessionId = result[0];
        _sessionManager = result[1];

        log.info('got link $sessionId, agent $_sessionManager');
        // We pass the sessionId and one side of the socket to the agent.
        // We will then be able to communicate back and forth via `client`.
        return _sessionManager.connectSession(sessionId, pair.second);
      })
      .catchError(
          (err, trace) => log.severe('failed to get link or agent', err, trace))
      .then((_) => log.info('session agent resolved'));

  _driver
      .start()
      .then((_) => trace('driver started'))
      .catchError((err, trace) => log.warning('driver error', err, trace));

  log.info('Starting embeddable_xi');

  runApp(new EmbeddedEditor(
    client: client,
    debugBackground: kDrawDebugBackground,
  ));
}

// TODO: Refactor this class to use the new SDK instead of deprecated API
// ignore: deprecated_member_use
Future<String> _getLink(ModuleDriver _driver) async {
  var link = await _driver.getLink('session-id');
  fuchsia_mem.Buffer buffer = await link.get();
  var dataVmo = new SizedVmo(buffer.vmo.handle, buffer.size);
  var data = dataVmo.read(buffer.size);
  dataVmo.close();
  return jsonDecode(utf8.decode(data.bytesAsUint8List()));
}

// TODO: Refactor this class to use the new SDK instead of deprecated API
// ignore: deprecated_member_use
Future<XiSessionManager> _getSessionManager(ModuleDriver _driver) async {
  XiSessionManagerProxy sessionManagerProxy = new XiSessionManagerProxy();
  return _driver
      .connectToAgentServiceWithAsyncProxy(
          kSessionManagerURL, sessionManagerProxy)
      .then((_) => sessionManagerProxy)
      .catchError((err, stackTrace) => log.severe(
          'error connecting to xi_session_manager', err, stackTrace));
}
