// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:lib.app.dart/app.dart';
import 'package:lib.context.fidl/debug.fidl.dart';
import 'package:lib.user_intelligence.fidl/scope.fidl.dart';

import 'data_handler.dart';

// ignore_for_file: public_member_api_docs

class ContextDataHandler extends ContextDebugListener with DataHandler {
  @override
  String get name => 'context';

  // ignore: avoid_annotating_with_dynamic
  final JsonCodec json = new JsonCodec(toEncodable: (dynamic object) {
    if (object is ComponentScope) {
      switch (object.tag) {
        case ComponentScopeTag.globalScope:
          return <String, dynamic>{'type': 'global'};
        case ComponentScopeTag.moduleScope:
          return <String, dynamic>{
            'type': 'module',
            'url': object.moduleScope.url,
            'storyId': object.moduleScope.storyId
          };
        case ComponentScopeTag.agentScope:
          return <String, dynamic>{
            'type': 'agent',
            'url': object.agentScope.url
          };
        default:
          return <String, dynamic>{'type': 'unknown'};
      }
    } else {
      return object.toJson();
    }
  });

  // cache for current state
  final Map<String, ContextDebugSubscription> _subscriptionsCache =
      <String, ContextDebugSubscription>{};
  final Map<String, ContextDebugValue> _valuesCache =
      <String, ContextDebugValue>{};

  // connection to context debug
  ContextDebugListenerBinding _contextDebugListenerBinding;

  SendWebSocketMessage _sendMessage;

  @override
  void init(ApplicationContext appContext, SendWebSocketMessage sender) {
    _sendMessage = sender;

    final ContextDebugProxy contextDebug = new ContextDebugProxy();
    connectToService(appContext.environmentServices, contextDebug.ctrl);
    assert(contextDebug.ctrl.isBound);

    // Watch subscription changes.
    _contextDebugListenerBinding = new ContextDebugListenerBinding();
    contextDebug.watch(_contextDebugListenerBinding.wrap(this));
    contextDebug.ctrl.close();
  }

  @override
  bool handleRequest(String requestString, HttpRequest request) {
    return false;
  }

  @override
  void handleNewWebSocket(WebSocket socket) {
    // Send all cached context data to the new socket.
    socket.add(_encode());
  }

  @override
  void onValuesChanged(List<ContextDebugValue> values) {
    for (ContextDebugValue update in values) {
      if (update.value != null) {
        // This is a new value or an update.
        _valuesCache[update.id] = update;
      } else {
        // This is a removal.
        _valuesCache.remove(update.id);
      }
    }
    _send();
  }

  @override
  void onSubscriptionsChanged(List<ContextDebugSubscription> subscriptions) {
    for (ContextDebugSubscription update in subscriptions) {
      if (update.query != null) {
        // This is a new subscription.
        _subscriptionsCache[update.id] = update;
      } else {
        // This is a removal.
        _subscriptionsCache.remove(update.id);
      }
    }
    _send();
  }

  String _encode() {
    // TODO(thatguy): It would be better to send the frontend updates as they
    // come in instead of storing a bunch of state here. In order to do that
    // we'd have to have each new web-socket get its own listener, so that
    // it is sent a complete state snapshot from the ContextEngine when it is
    // initialized in handleNewWebSocket().
    final String message = json.encode(<String, dynamic>{
      'context.values': new List<ContextDebugValue>.from(_valuesCache.values),
      'context.subscriptions':
          new List<ContextDebugSubscription>.from(_subscriptionsCache.values)
    });
    return message;
  }

  void _send() {
    _sendMessage(_encode());
  }
}
