// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:lib.app.dart/app.dart';
import 'package:fidl_modular/fidl.dart';

import 'data_handler.dart';

// ignore_for_file: public_member_api_docs

class ContextDataHandler extends ContextDebugListener with DataHandler {
  @override
  String get name => 'context';

  final JsonCodec json = new JsonCodec(toEncodable: (object) {
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

  static Map<String, dynamic> _encodeContextMetadata(ContextMetadata metadata) {
    if (metadata == null) {
      return null;
    }
    Map<String, dynamic> json = <String, dynamic>{};
    if (metadata.story != null) {
      json['story'] = <String, dynamic>{
        'id': metadata.story.id,
        'focused': <String, int>{'state': metadata.story.focused.state.value}
      };
    }
    if (metadata.mod != null) {
      json['mod'] = <String, dynamic>{
        'url': metadata.mod.url,
        'path': metadata.mod.path
      };
    }
    if (metadata.entity != null) {
      json['entity'] = <String, dynamic>{
        'topic': metadata.entity.topic,
        'type': metadata.entity.type
      };
    }
    if (metadata.link != null) {
      json['link'] = <String, dynamic>{
        'modulePath': metadata.link.modulePath,
        'name': metadata.link.name
      };
    }

    return json;
  }

  static Map<String, dynamic> _encodeContextDebugValue(
      ContextDebugValue value) {
    return <String, dynamic>{
      'id': value.id,
      'parentIds': value.parentIds,
      'value': <String, dynamic>{
        'type': value.value.type.value,
        'content': value.value.content,
        'meta': _encodeContextMetadata(value.value.meta),
      }
    };
  }

  static Map<String, dynamic> _encodeContextDebugSubscription(
      ContextDebugSubscription sub) {
    return <String, dynamic>{
      'id': sub.id,
      // TODO(ianloic): add debugInfo if needed
      'query': <String, dynamic>{
        'selector': sub.query.selector
            .map((ContextQueryEntry entry) => <String, dynamic>{
                  'key': entry.key,
                  'value': <String, dynamic>{
                    'meta': _encodeContextMetadata(entry.value.meta),
                    'type': entry.value.type.value
                  }
                })
            .toList()
      }
    };
  }

  String _encode() {
    // TODO(thatguy): It would be better to send the frontend updates as they
    // come in instead of storing a bunch of state here. In order to do that
    // we'd have to have each new web-socket get its own listener, so that
    // it is sent a complete state snapshot from the ContextEngine when it is
    // initialized in handleNewWebSocket().
    final String message = json.encode(<String, dynamic>{
      'context.values':
          _valuesCache.values.map(_encodeContextDebugValue).toList(),
      'context.subscriptions': _subscriptionsCache.values
          .map(_encodeContextDebugSubscription)
          .toList(),
    });
    return message;
  }

  void _send() {
    _sendMessage(_encode());
  }
}
