// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show utf8;

import 'package:fidl_fuchsia_modular/fidl_async.dart' as modular;
import 'package:fidl_fuchsia_xi_session/fidl_async.dart';
import 'package:fuchsia_scenic_flutter/child_view_connection.dart'
    show ChildViewConnection;
import 'package:fuchsia_logger/logger.dart';
import 'package:fuchsia_modular/module.dart';
import 'package:fuchsia_modular/service_connection.dart';
import 'package:lib.widgets.dart/model.dart';

const String kSessionManagerURL =
    'fuchsia-pkg://fuchsia.com/xi_session_agent#meta/xi_session_agent.cmx';

class DemoModel extends Model {
  final List<String> messages = [
    'Hello!',
    'This is pretending to be a messaging app.',
    'Press "+" to open a compose view',
    'Then press "send" to add a message.',
  ];

  final _sessionManagerProxy = XiSessionManagerProxy();
  XiSessionManager get sessionManager => _sessionManagerProxy;

  DemoModel() {
    connectToAgentService(kSessionManagerURL, _sessionManagerProxy);
  }

  modular.ModuleController editorController;
  ChildViewConnection _editorConn;
  ChildViewConnection get editorConn => _editorConn;

  set editorConn(ChildViewConnection editorConn) {
    log.fine('Setting child editor view connection to $editorConn');
    _editorConn = editorConn;
    notifyListeners();
  }

  /// The session identifier for the active editing session.
  String _activeSession;

  /// `true` iff we are showing the modal 'compose' view.
  bool showingModal = false;

  /// Creates a new xi session, and starts embeddable_xi as a child mod
  /// in a new modal view.
  void composeButtonAction() async {
    _activeSession = await requestSessionId();
    await connectXiModule(_activeSession);
    log.info('connecting session $_activeSession');
    showingModal = true;
    notifyListeners();
  }

  /// Fetches the contents of the modal view from the agent, adds them
  /// as a new message to the messages list, and dismisses the modal.
  void sendButtonAction() async {
    log.info('requesting contents for $_activeSession');

    final vmo = await sessionManager.getContents(_activeSession);
    final newMessage = vmo.read(vmo.getSize().size).bytesAsUTF8String();

    messages.add(newMessage);
    if (editorController != null) {
      await editorController.stop();
    }
    _editorConn = null;
    showingModal = false;
    notifyListeners();
  }

  /// Requests a new session id from the xi session agent service.
  Future<String> requestSessionId() => sessionManager.newSession();

  Future<void> connectXiModule(String sessionId) async {
    final entity = await Module()
        .createEntity(type: 'string', initialData: utf8.encode(sessionId));

    final intent = Intent(
        action: '',
        handler:
            'fuchsia-pkg://fuchsia.com/xi_embeddable#meta/xi_embeddable.cmx')
      ..addParameterFromEntityReference(
          'session-id', await entity.getEntityReference());

    final embeddedModule =
        await Module().embedModule(name: 'xi_embeddable', intent: intent);

    _editorConn = ChildViewConnection(embeddedModule.viewHolderToken);
    editorController = embeddedModule.moduleController;
  }
}
