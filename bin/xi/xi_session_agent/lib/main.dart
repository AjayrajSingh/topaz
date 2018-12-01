// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_auth/fidl.dart';
import 'package:fidl_fuchsia_xi_session/fidl.dart' as fidl_xi_session;

import 'package:lib.app.dart/app.dart';
import 'package:lib.agent.dart/agent.dart';
import 'package:lib.app.dart/logging.dart';

import 'package:meta/meta.dart';
import 'package:zircon/zircon.dart';

import 'package:xi_fuchsia_client/client.dart';
import 'package:xi_client/client.dart';

/// ignore_for_file: avoid_annotating_with_dynamic

class PendingNotification {
  final String method;
  final dynamic params;
  PendingNotification(this.method, this.params);
}


/// TODO: Refactor this class to use the new SDK instead of deprecated API
/// ignore: deprecated_member_use
class XiSessionAgent extends AgentImpl {
  final _xiSessionManager = XiSessionManagerImpl();

  final List<fidl_xi_session.XiSessionManagerBinding> _bindings =
      <fidl_xi_session.XiSessionManagerBinding>[];

  XiSessionAgent({@required StartupContext startupContext})
      : super(startupContext: startupContext);

  @override
  Future<Null> onReady(
    StartupContext startupContext,
    AgentContext agentContext,
    ComponentContext componentContext,
    TokenManager tokenManager,
    ServiceProviderImpl outgoingServices,
  ) async {
    outgoingServices.addServiceForName(
      (InterfaceRequest<fidl_xi_session.XiSessionManager> request) {
        log.info('got request $request');
        _bindings.add(
          fidl_xi_session.XiSessionManagerBinding()
            ..bind(_xiSessionManager, request),
        );
      },
      fidl_xi_session.XiSessionManager.$serviceName,
    );
  }

  @override
  void advertise() {
    super.advertise();
    log.info('advertising xi_session_agent');
  }
}

class XiSessionManagerImpl extends fidl_xi_session.XiSessionManager
    implements XiRpcHandler {
  int _sessionId = 0;
  final XiFuchsiaClient xiCore;

  /// A map of session identifiers to view identifiers. These are sessions
  /// that a client can connect to.
  final Map<String, String> _availableSessions = {};

  /// A map of in-use sessions to view identifiers.
  final Map<String, String> _activeSessions = {};

  /// A map of core view identifiers to active connections
  final Map<String, ViewForwarder> _activeConnections = {};
  final Map<String, List<PendingNotification>> _pending = {};

  XiSessionManagerImpl() : xiCore = XiFuchsiaClient(null) {
    xiCore.handler = this;
    xiCore.init().then((_) => xiCore.sendNotification('client_started', {}));
  }

  @override
  void newSession(void Function(String sessionId) callback) {
    int id = _sessionId++;
    String idString = 'session-$id';
    xiCore.sendRpc('new_view', {}).then((viewId) {
      _availableSessions[idString] = viewId;
      log.info('associated session $idString with view $viewId');
    });
    callback(idString);
  }

  @override
  void closeSession(String sessionId) {
    final viewId = _activeSessions.remove(sessionId);
    if (viewId == null) {
      log.warning('attempted to close unknown session $sessionId');
    }
    _activeConnections.remove(viewId);
    xiCore.sendRpc('close_view', {'view_id': viewId});
  }

  @override
  void connectSession(String sessionId, Socket socket) {
    final viewId = _availableSessions.remove(sessionId);
    if (viewId == null) {
      log.warning('attempted to connect to unknown session $sessionId');
    }
    final forwarder = ViewForwarder(socket, viewId, xiCore)..init();
    _activeConnections[viewId] = forwarder;
    _activeSessions[sessionId] = viewId;
    log.info('connecting session $sessionId to view $viewId');
    final pending = _pending.remove(viewId);
    if (pending != null) {
      for (var notif in pending) {
        forwarder.sendNotification(notif.method, notif.params);
      }
    }
  }

  @override
  void getContents(String sessionId, void Function(Vmo buffer) callback) {
    final viewId = _activeSessions[sessionId];
    if (viewId == null) {
      log.warning('getContents called for unknown session $sessionId');
      callback(SizedVmo.fromUint8List(utf8.encode('unknown session id?? o_O')));
      return;
    }

    xiCore.sendRpc('debug_get_contents', {'view_id': viewId}).then((result) {
      String contents = result;
      final vmo = SizedVmo.fromUint8List(utf8.encode(contents));
      callback(vmo);
    }).catchError((err) {
      log.warning('get_contents failed for view $viewId', err);
      callback(SizedVmo.fromUint8List(utf8.encode('getContents err $err')));
    });
  }

  // handle a notification from xi-core, forwarding it to some session
  @override
  void handleNotification(String method, dynamic params) {
    String viewId = params.remove('view_id');
    if (viewId == null) {
      // we ignore things that aren't for a view
      log.warning('ignoring notification $method $params');
      return;
    }

    final session = _activeConnections[viewId];
    if (session == null) {
      log.info(
          'no session active for view $viewId. Active connections: $_activeConnections');
      _pending.putIfAbsent(viewId, () => []);
      _pending[viewId].add(PendingNotification(method, params));
    } else {
      session.sendNotification(method, params);
    }
  }

  @override
  dynamic handleRpc(String method, dynamic params) {
    return 'session requests not implemeneted';
  }
}

/// Main entry point to the example parent module.
void main(List<String> args) {
  setupLogger(name: '[xi_session_agent]');
  log.info('agent started');

  new XiSessionAgent(
    startupContext: StartupContext.fromStartupInfo(),
  ).advertise();
}

class ViewForwarder extends XiClient implements XiRpcHandler {
  final Socket _socket;
  final SocketReader _reader = new SocketReader();
  final String viewId;
  final XiClient core;

  ViewForwarder(this._socket, this.viewId, this.core)
      : assert(_socket != null),
        assert(core != null),
        assert(viewId != null) {
    handler = this;
  }

  @override
  Future<Null> init() async {
    _reader
      ..bind(_socket)
      ..onReadable = handleRead;
  }

  @override
  void send(String data) {
    final List<int> ints = utf8.encode('$data\n');
    final Uint8List bytes = new Uint8List.fromList(ints);
    final ByteData buffer = bytes.buffer.asByteData();

    final WriteResult result = _reader.socket.write(buffer);

    if (result.status != ZX.OK) {
      StateError error = new StateError('ERROR WRITING: $result');
      streamController
        ..addError(error)
        ..close();
    }
  }

  void handleRead() {
    // TODO(pylaligand): the number of bytes below is bogus.
    final ReadResult result = _reader.socket.read(1000);

    if (result.status != ZX.OK) {
      StateError error = new StateError('Socket read error: ${result.status}');
      streamController
        ..addError(error)
        ..close();
      return;
    }

    String resultAsString = result.bytesAsUTF8String();
    // TODO: use string directly, avoid re-roundtrip
    List<int> fragment = utf8.encode(resultAsString);
    streamController.add(fragment);
  }

  @override
  void handleNotification(String method, dynamic params) {
    Map<String, dynamic> outer = {
      'view_id': viewId,
      'method': method,
      'params': params,
    };
    core.sendNotification('edit', outer);
  }

  @override
  Future<dynamic> handleRpc(String method, dynamic params) {
    Map<String, dynamic> outer = {
      'view_id': viewId,
      'method': method,
      'params': params,
    };
    return core.sendRpc('edit', outer);
  }
}
