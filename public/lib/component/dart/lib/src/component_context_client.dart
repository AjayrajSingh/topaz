// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl.dart' as fidl;
import 'package:fidl_fuchsia_sys/fidl.dart' as fidl;
import 'package:lib.app.dart/logging.dart';
import 'package:lib.component.dart/component.dart';
import 'package:lib.entity.dart/entity.dart';
import 'package:meta/meta.dart';

/// A client wrapper for [fidl.ComponentContext].
class ComponentContextClient {
  /// The underlying [Proxy] used to send client requests to the
  /// [fidl.ComponentContextProxy] service.
  final fidl.ComponentContextProxy proxy = new fidl.ComponentContextProxy();

  final EntityResolverClient _entityResolver = new EntityResolverClient();

  // Keep track of agent controllers created to close the channels onTerminate
  final List<fidl.AgentControllerProxy> _agentControllers =
      <fidl.AgentControllerProxy>[];

  /// Constructor.
  ComponentContextClient() {
    proxy.ctrl
      ..onBind = _handleBind
      ..onClose = _handleClose
      ..onConnectionError = _handleConnectionError
      ..onUnbind = _handleUnbind;
  }

  /// A future that completes when the [proxy] is bound.
  Future<Null> get bound => _bind.future;
  final Completer<Null> _bind = new Completer<Null>();

  /// See [fidl.ComponentContext#createEntityWithData].
  Future<String> createEntityWithData(List<fidl.TypeToDataEntry> typeToData) {
    Completer<String> completer = new Completer<String>();

    // ignore: unawaited_futures
    proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    void onSuccess(String value) {
      if (!completer.isCompleted) {
        if (value != null) {
          completer.complete(value);
        } else {
          completer.completeError(new Exception('entity reference is null'));
        }
      }
    }

    try {
      proxy.createEntityWithData(typeToData, onSuccess);
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }

    return completer.future;
  }

  /// See [fidl.ComponentContext#getEntityResolver].
  Future<EntityResolverClient> getEntityResolver() async {
    if (_entityResolver.proxy.ctrl.isBound) {
      return _entityResolver;
    }

    Completer<EntityResolverClient> completer =
        new Completer<EntityResolverClient>();

    try {
      await bound;
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }

    // ignore: unawaited_futures
    proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    // ignore: unawaited_futures
    _entityResolver.proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    try {
      proxy.getEntityResolver(_entityResolver.proxy.ctrl.request());
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }

    scheduleMicrotask(() {
      if (!completer.isCompleted) {
        completer.complete(_entityResolver);
      }
    });

    return completer.future;
  }

  /// Obtain a named message queue for receiving messages.
  MessageQueueClient obtainMessageQueue(
      {@required String name,
      @required MessageReceiverCallback onMessage,
      @required MessageQueueErrorCallback onConnectionError}) {
    var mq = new MessageQueueClient(
        onMessage: onMessage, onConnectionError: onConnectionError);
    proxy.obtainMessageQueue(name, mq.newRequest());
    return mq;
  }

  /// Obtain a message queue sender from a token.
  MessageSenderClient getMessageSender(
      {@required String queueToken,
      @required MessageSenderErrorCallback onConnectionError}) {
    var sender = new MessageSenderClient(onConnectionError: onConnectionError);
    proxy.getMessageSender(queueToken, sender.newRequest());
    return sender;
  }

  /// Connect to an agent
  Future<fidl.ServiceProviderProxy> connectToAgent(String url) {
    Completer<fidl.ServiceProviderProxy> serviceCompleter =
        new Completer<fidl.ServiceProviderProxy>();

    // Connect to the agent and save off the agent controller proxy to be
    // closed on terminate
    fidl.ServiceProviderProxy serviceProviderProxy =
        new fidl.ServiceProviderProxy();
    serviceProviderProxy.ctrl.error.then((ProxyError err) {
      if (!serviceCompleter.isCompleted) {
        serviceCompleter.completeError(err);
      }
    });

    fidl.AgentControllerProxy agentControllerProxy =
        new fidl.AgentControllerProxy();
    _agentControllers.add(agentControllerProxy);
    agentControllerProxy.ctrl.error.then((ProxyError err) {
      if (!serviceCompleter.isCompleted) {
        serviceCompleter.completeError(err);
      }
    });

    proxy.connectToAgent(
      url,
      serviceProviderProxy.ctrl.request(),
      agentControllerProxy.ctrl.request(),
    );

    scheduleMicrotask(() {
      if (!serviceCompleter.isCompleted) {
        serviceCompleter.complete(serviceProviderProxy);
      }
    });

    return serviceCompleter.future;
  }

  /// See [fidl.ComponentContext#getPackageName].
  Future<String> getPackageName() {
    Completer<String> completer = new Completer<String>();
    try {
      proxy.getPackageName(completer.complete);
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }
    return completer.future;
  }

  void _handleConnectionError() {
    log.warning('ComponentContextClient connection error');
  }

  void _handleBind() {
    log.fine('proxy ready');
    _bind.complete(null);
  }

  void _handleUnbind() {
    log.fine('proxy unbound');
  }

  void _handleClose() {
    log.fine('proxy closed');

    for (fidl.AgentControllerProxy p in _agentControllers) {
      p.ctrl.close();
    }
  }

  /// Closes the underlying proxy connection, should be called as a response to
  /// Lifecycle::terminate (see https://goo.gl/MmZ2dc).
  Future<Null> terminate() async {
    log.info('terminate called');
    proxy.ctrl.close();
    return;
  }
}
