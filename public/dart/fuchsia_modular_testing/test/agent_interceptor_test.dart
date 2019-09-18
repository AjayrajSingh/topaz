// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

// ignore_for_file: implementation_imports
import 'package:fuchsia_modular_testing/src/test_harness_spec_builder.dart';
import 'package:fuchsia_modular_testing/test.dart';
import 'package:test/test.dart';
import 'package:fidl/fidl.dart' as fidl;
import 'package:fidl_fuchsia_modular_testing/fidl_async.dart';
import 'package:fuchsia_logger/logger.dart';
import 'package:fuchsia_modular_testing/src/agent_interceptor.dart';
import 'package:fuchsia_modular_testing/src/test_harness_fixtures.dart';
import 'package:fuchsia_modular/service_connection.dart';
import 'package:fidl_test_modular_dart/fidl_async.dart';

void main() {
  setupLogger();

  group('mock registration', () {
    AgentInterceptor agentInterceptor;

    setUp(() {
      agentInterceptor =
          AgentInterceptor(Stream<TestHarness$OnNewComponent$Response>.empty());
    });

    test('mockAgent throws for null agentUrl', () {
      expect(
          () => agentInterceptor.mockAgent(null, (_) {}), throwsArgumentError);
    });

    test('mockAgent throws for empty agentUrl', () {
      expect(() => agentInterceptor.mockAgent('', (_) {}), throwsArgumentError);
    });

    test('mockAgent throws for missing callback', () {
      expect(() => agentInterceptor.mockAgent(generateComponentUrl(), null),
          throwsArgumentError);
    });

    test('mockAgent throws for registering agent twice', () {
      final agentUrl = generateComponentUrl();
      void callback(_) {}

      agentInterceptor.mockAgent(agentUrl, callback);

      expect(() => agentInterceptor.mockAgent(agentUrl, callback),
          throwsException);
    });
  });

  group('agent intercepting', () {
    TestHarnessProxy harness;
    String agentUrl;

    setUp(() async {
      agentUrl = generateComponentUrl();
      harness = await launchTestHarness();
    });

    tearDown(() {
      harness.ctrl.close();
    });

    test('onNewAgent called for mocked agent', () async {
      final spec =
          (TestHarnessSpecBuilder()..addComponentToIntercept(agentUrl)).build();

      final didCallCompleter = Completer<bool>();
      AgentInterceptor(harness.onNewComponent).mockAgent(agentUrl, (agent) {
        expect(agent, isNotNull);
        didCallCompleter.complete(true);
      });

      await harness.run(spec);

      final componentContext = await getComponentContext(harness);
      final proxy = ServerProxy();
      connectToAgentService(agentUrl, proxy,
          componentContextProxy: componentContext);
      componentContext.ctrl.close();
      proxy.ctrl.close();

      expect(await didCallCompleter.future, isTrue);
    });

    test('onNewAgent can expose a service', () async {
      final spec =
          (TestHarnessSpecBuilder()..addComponentToIntercept(agentUrl)).build();

      final server = _ServerImpl();
      AgentInterceptor(harness.onNewComponent).mockAgent(agentUrl, (agent) {
        agent.exposeService(server);
      });

      await harness.run(spec);

      final fooProxy = ServerProxy();
      final componentContext = await getComponentContext(harness);
      connectToAgentService(agentUrl, fooProxy,
          componentContextProxy: componentContext);

      expect(await fooProxy.echo('some value'), 'some value');

      fooProxy.ctrl.close();
      componentContext.ctrl.close();
    });

    test('onNewAgent can expose a service generically', () async {
      final spec =
          (TestHarnessSpecBuilder()..addComponentToIntercept(agentUrl)).build();

      for (final server in <fidl.Service>[_ServerImpl()]) {
        AgentInterceptor(harness.onNewComponent).mockAgent(agentUrl, (agent) {
          agent.exposeService(server);
        });
      }

      await harness.run(spec);

      final fooProxy = ServerProxy();
      final componentContext = await getComponentContext(harness);
      connectToAgentService(agentUrl, fooProxy,
          componentContextProxy: componentContext);

      expect(await fooProxy.echo('some value'), 'some value');

      fooProxy.ctrl.close();
      componentContext.ctrl.close();
    });
  });
}

class _ServerImpl extends Server {
  @override
  Future<String> echo(String value) async {
    return value;
  }
}
