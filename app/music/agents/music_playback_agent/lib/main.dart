// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:application.lib.app.dart/app.dart';
import 'package:application.services/service_provider.fidl.dart';
import 'package:apps.modular.services.agent/agent.fidl.dart';
import 'package:apps.modular.services.agent/agent_context.fidl.dart';
import 'package:apps.modules.music.services.player/player.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';

import 'src/player_impl.dart';

final ApplicationContext _context = new ApplicationContext.fromStartupInfo();
MusicPlaybackAgent _agent;

void _log(String msg) {
  print('[music_playback_agent] $msg');
}

/// An [Agent] that provides access fo the music player service
class MusicPlaybackAgent extends Agent {
  final AgentBinding _agentBinding = new AgentBinding();

  final ServiceProviderImpl _outgoingServicesImpl = new ServiceProviderImpl();
  final List<ServiceProviderBinding> _outgoingServicesBindings =
      <ServiceProviderBinding>[];

  PlayerImpl _playerImpl;

  /// Bind an [InterfaceRequest] for an [Agent] interface to this object.
  void bind(InterfaceRequest<Agent> request) {
    _agentBinding.bind(this, request);
  }

  @override
  Future<Null> initialize(
      InterfaceHandle<AgentContext> agentContextHandle, void callback()) async {
    _log('Agent::initialize start.');

    // Initialize the player service
    _playerImpl = new PlayerImpl();

    // Register the player service to the outgoingServices service provider
    _outgoingServicesImpl.addServiceForName(
      (InterfaceRequest<PlayerImpl> request) {
        _log('Received a ChatContentProvider request');
        _playerImpl.addBinding(request);
      },
      Player.serviceName,
    );

    _log('Agent::initialize end.');

    callback();
  }

  /// Implements [Agent] interface.
  @override
  Future<Null> connect(
    String requestorUrl,
    InterfaceRequest<ServiceProvider> services,
  ) async {
    _log('Agent::connect call from $requestorUrl.');
    _outgoingServicesBindings.add(
      new ServiceProviderBinding()..bind(_outgoingServicesImpl, services),
    );
  }

  /// Implements [Agent] interface.
  @override
  void runTask(String taskId, void callback()) {}

  /// Implements [Agent] interface.
  @override
  void stop(void callback()) {
    _outgoingServicesBindings
        .forEach((ServiceProviderBinding binding) => binding.close());

    callback();
  }
}

/// Main entry point.
Future<Null> main(List<String> args) async {
  _context.outgoingServices.addServiceForName(
      (InterfaceRequest<Agent> request) {
    if (_agent == null) {
      _agent = new MusicPlaybackAgent()..bind(request);
    } else {
      // Can only connect to this interface once.
      request.close();
    }
  }, Agent.serviceName);
}
