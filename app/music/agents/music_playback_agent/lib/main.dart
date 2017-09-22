// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';

import 'package:lib.agent.fidl/agent.fidl.dart';
import 'package:lib.agent.fidl/agent_context.fidl.dart';
import 'package:lib.lifecycle.fidl/lifecycle.fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.fidl/service_provider.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.logging/logging.dart';
import 'package:topaz.app.music.services.player/player.fidl.dart';

import 'src/player_impl.dart';

final ApplicationContext _context = new ApplicationContext.fromStartupInfo();
MusicPlaybackAgent _agent = new MusicPlaybackAgent();

/// An [Agent] that provides access fo the music player service
// TODO(youngseokyoon): use AgentImpl in music_playback_agent.
// https://fuchsia.atlassian.net/browse/SO-539
class MusicPlaybackAgent implements Agent, Lifecycle {
  final AgentBinding _agentBinding = new AgentBinding();
  final LifecycleBinding _lifecycleBinding = new LifecycleBinding();

  final ServiceProviderImpl _outgoingServicesImpl = new ServiceProviderImpl();
  final List<ServiceProviderBinding> _outgoingServicesBindings =
      <ServiceProviderBinding>[];

  PlayerImpl _playerImpl;

  /// Bind an [InterfaceRequest] for an [Agent] interface to this object.
  void bind(InterfaceRequest<Agent> request) {
    if (!_agentBinding.isBound) {
      _agentBinding.bind(this, request);
    } else {
      request.close();
    }
  }

  /// Bind an [InterfaceRequest] for a [Lifecycle] interface to this object.
  void bindLifecycle(InterfaceRequest<Lifecycle> request) {
    if (!_lifecycleBinding.isBound) {
      _lifecycleBinding.bind(this, request);
    } else {
      request.close();
    }
  }

  @override
  Future<Null> initialize(
      InterfaceHandle<AgentContext> agentContextHandle, void callback()) async {
    log.fine('Agent::initialize start.');

    // Initialize the player service
    _playerImpl = new PlayerImpl(_context);

    // Register the player service to the outgoingServices service provider
    _outgoingServicesImpl.addServiceForName(
      (InterfaceRequest<PlayerImpl> request) {
        log.fine('Received a Player request');
        _playerImpl.addBinding(request);
      },
      Player.serviceName,
    );

    log.fine('Agent::initialize end.');

    callback();
  }

  /// Implements [Agent] interface.
  @override
  Future<Null> connect(
    String requestorUrl,
    InterfaceRequest<ServiceProvider> services,
  ) async {
    log.fine('Agent::connect call from $requestorUrl.');
    _outgoingServicesBindings.add(
      new ServiceProviderBinding()..bind(_outgoingServicesImpl, services),
    );
  }

  /// Implements [Agent] interface.
  @override
  void runTask(String taskId, void callback()) {}

  /// Implements [Lifecycle] interface.
  @override
  void terminate() {
    _agentBinding.close();
    _lifecycleBinding.close();
    _outgoingServicesBindings
        .forEach((ServiceProviderBinding binding) => binding.close());
    Isolate.current.kill();
  }
}

/// Main entry point.
Future<Null> main(List<String> args) async {
  setupLogger();

  _context.outgoingServices
    ..addServiceForName((InterfaceRequest<Agent> request) {
      _agent.bind(request);
    }, Agent.serviceName)
    ..addServiceForName((InterfaceRequest<Lifecycle> request) {
      _agent.bindLifecycle(request);
    }, Lifecycle.serviceName);
}
