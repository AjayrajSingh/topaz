// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_fidl_examples_bindingstest/fidl.dart' as fidlgen;
import 'package:fidl_fidl_examples_bindingstest/fidl_async.dart';
import 'package:test/test.dart';

import './server.dart';

void main() async {
  TestServerInstance server;
  group('failure', () {
    setUp(() async {
      server = new TestServerInstance();
      await server.start();
    });

    tearDown(() async {
      if (server != null) {
        await server.stop();
      }
      server = null;
    });

    test('remote close during call', () async {
      expect(server.proxy.replySlowly('hey man', 1.0), throwsA(anything));
      return server.proxy.closeConnection(0.1);
    });

    test('local close during call', () async {
      expect(server.proxy.replySlowly('whoa dude', 1.0), throwsA(anything));
      server.proxy.ctrl.close();
    });

    test('server killed during call', () async {
      expect(server.proxy.replySlowly('whoa dude', 1.0), throwsA(anything));
      return server.controller.kill();
    });

    test('one-way call on closed proxy', () {
      server.proxy.ctrl.close();
      expect(server.proxy.oneWayNoArgs(), throwsA(anything));
    });

    test('two-way call on closed proxy', () {
      server.proxy.ctrl.close();
      expect(server.proxy.twoWayNoArgs(), throwsA(anything));
    });

    test('listen for events on a closed proxy', () {
      server.proxy.ctrl.close();
      expect(server.proxy.emptyEvent.first, throwsA(anything));
    });

    test('proxy closes while listening for events', () {
      expect(server.proxy.emptyEvent.first, throwsA(anything));
      server.proxy.ctrl.close();
    });

    test('binding closes immediately after sending response', () async {
      var impl = new SimpleServerImpl();
      var proxy = impl.newAsyncProxy();
      var pinged = false;

      Future<Null> pingFut = proxy.ping().then((_) {
        pinged = true;
      });
      var closedFut = proxy.ctrl.whenClosed.then((_) {
        expect(pinged, equals(true));
      });
      await Future.wait([pingFut, closedFut]);
    });
  });

  group('unbound', () {
    test('one-way call on unbound proxy', () {
      final proxy = new TestServerProxy();
      expect(proxy.oneWayNoArgs(), throwsA(anything));
    });
    test('two-way call on unbound proxy', () {
      final proxy = new TestServerProxy();
      expect(proxy.twoWayNoArgs(), throwsA(anything));
    });
    test('event listen on unbound proxy', () {
      final proxy = new TestServerProxy();
      expect(proxy.emptyEvent.first, doesNotComplete);
    });
  });
}

// This implementation uses the callback-based bindings, since the future-based
// bindings don't cleanly allow SimpleServerImpl.ping() to respond and then
// close the bound channel.
class SimpleServerImpl extends fidlgen.SimpleServer {
  SimpleServerProxy newAsyncProxy() {
    var proxy = new SimpleServerProxy();
    binding.bind(
        this,
        InterfaceRequest<fidlgen.SimpleServer>(
            proxy.ctrl.request().passChannel()));
    return proxy;
  }

  @override
  void ping(void callback()) {
    callback();
    binding.close();
  }

  fidlgen.SimpleServerBinding binding = new fidlgen.SimpleServerBinding();
}
