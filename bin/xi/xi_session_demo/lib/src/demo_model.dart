// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:fidl_fuchsia_ui_viewsv1token/fidl.dart';
import 'package:fidl_fuchsia_xi_session/fidl_async.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.widgets.dart/model.dart';

const String kSessionManagerURL =
    'fuchsia-pkg://fuchsia.com/xi_session_agent#meta/xi_session_agent.cmx';

class DemoModel extends Model {
  /// TODO: Refactor this class to use the new SDK instead of deprecated API
  /// ignore: deprecated_member_use
  final ModuleDriver driver = ModuleDriver();
  final List<String> messages = [
    'Hello!',
    'This is pretending to be a messaging app.',
    'Press "+" to open a compose view',
    'Then press "send" to add a new message.',
  ];

  XiSessionManager _sessionManager;
  Future<XiSessionManager> _pendingManager;

  DemoModel() {
    driver.start().then((driver) => trace('ModuleDriver started')).catchError(
        (error, trace) => log.severe('ModuleDriver errored:', error, trace));

    XiSessionManagerProxy sessionManagerProxy = new XiSessionManagerProxy();
    _pendingManager = driver
        .connectToAgentServiceWithAsyncProxy(
            kSessionManagerURL, sessionManagerProxy)
        .then((_) => _sessionManager = sessionManagerProxy)
        .catchError((err, stackTrace) => log.severe(
            'error connecting to xi_session_manager', err, stackTrace));
  }

  Future<XiSessionManager> get sessionManager => (_sessionManager == null)
      ? _pendingManager
      : Future.value(_sessionManager);

  InterfacePair<ViewOwner> viewOwner;
  ModuleControllerClient editorController;
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
    connectXiModule(_activeSession);
    log.info('connecting session $_activeSession');
    showingModal = true;
    notifyListeners();
  }

  /// Fetches the contents of the modal view from the agent, adds them
  /// as a new message to the messages list, and dismisses the modal.
  void sendButtonAction() async {
    log.info('requesting contents for $_activeSession');
    final newMessage = await sessionManager
        .then((manager) => manager.getContents(_activeSession))
        .then((vmo) => vmo.read(vmo.getSize().size).bytesAsUTF8String());
    messages.add(newMessage);
    //TODO: close the active session
    await editorController.stop();
    _editorConn = null;
    showingModal = false;
    notifyListeners();
  }

  /// Requests a new session id from the xi session agent service.
  Future<String> requestSessionId() async {
    var manager = await sessionManager;
    String result = await manager.newSession();
    return result;
  }

  void connectXiModule(String sessionId) async {
    viewOwner = InterfacePair();
    editorController = new ModuleControllerClient();
    IntentBuilder intentBuilder = new IntentBuilder.handler(
        'fuchsia-pkg://fuchsia.com/xi_embeddable#meta/xi_embeddable.cmx')
      ..addParameter('session-id', sessionId);
    driver.moduleContext.proxy.embedModule(
        'xi_embeddable',
        intentBuilder.intent,
        editorController.proxy.ctrl.request(),
        viewOwner.passRequest(), (StartModuleStatus status) {
      editorConn = ChildViewConnection(viewOwner.passHandle());
      log.info('Start embeddable intent status = $status');
    });
  }
}
