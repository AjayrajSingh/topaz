// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia.fidl.auth/auth.dart';
import 'package:fidl/fidl.dart';
import 'package:lib.logging/logging.dart';

import 'package:fuchsia.fidl.chat_content_provider/chat_content_provider.dart';

import 'firebase_db_client_impl.dart';

/// The implementation class for the [FirebaseDbConnector] FIDL interface.
class FirebaseDbConnectorImpl implements FirebaseDbConnector {
  /// The [TokenProvider] to pass to the individual [FirebaseDbClient]s.
  final TokenProvider tokenProvider;

  final List<FirebaseDbWatcherProxy> _watchers = <FirebaseDbWatcherProxy>[];
  final List<FirebaseDbClientBinding> _clientBindings =
      <FirebaseDbClientBinding>[];

  /// Creates a new instance of [FirebaseDbConnectorImpl].
  FirebaseDbConnectorImpl({this.tokenProvider});

  @override
  void getClient(
    InterfaceHandle<FirebaseDbWatcher> watcherHandle,
    InterfaceRequest<FirebaseDbClient> clientRequest,
  ) {
    log.fine('getClient call.');

    // Convert the watcher handle into a proxy object.
    FirebaseDbWatcherProxy watcher;
    if (watcherHandle != null) {
      watcher = new FirebaseDbWatcherProxy();
      watcher.ctrl.bind(watcherHandle);
      _watchers.add(watcher);
    }

    // Create a new client impl.
    FirebaseDbClientImpl client = new FirebaseDbClientImpl(
      tokenProvider: tokenProvider,
      watcher: watcher,
    );

    // Bind that impl class to the request.
    FirebaseDbClientBinding clientBinding = new FirebaseDbClientBinding()
      ..bind(client, clientRequest);

    // We want to clean up all the network connections when the underlying FIDL
    // channel for the client is closed.
    clientBinding.onConnectionError = () {
      client.terminate(() {});
      _clientBindings.remove(clientBinding);
    };

    _clientBindings.add(clientBinding);
  }
}
