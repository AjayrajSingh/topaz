// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fidl_fuchsia_mem/fidl.dart' as fuchsia_mem;
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.proposal.dart/proposal.dart';
import 'package:zircon/zircon.dart';

/// Manages the list of active agents and the proposals for showing them.
class ActiveAgentsManager {
  final _ActiveAgentProposer _activeAgentProposer = new _ActiveAgentProposer();

  final AgentProviderProxy _agentProvider = new AgentProviderProxy();

  final _AgentProviderWatcherImpl _agentProviderWatcherImpl =
      new _AgentProviderWatcherImpl(
    link: new LinkProxy(),
  );

  final AgentProviderWatcherBinding _agentProviderWatcherBinding =
      new AgentProviderWatcherBinding();

  _ProposalListener _proposalListener;

  /// Starts listening for active agent changes and begins proposing the agent
  /// module be run.
  void start(
    UserShellContext userShellContext,
    FocusProvider focusProvider,
    StoryProvider storyProvider,
    IntelligenceServices intelligenceServices,
  ) {
    userShellContext.getAgentProvider(_agentProvider.ctrl.request());
    _agentProvider.watch(
      _agentProviderWatcherBinding.wrap(_agentProviderWatcherImpl),
    );

    _proposalListener = new _ProposalListener(
      storyProvider: storyProvider,
      agentProviderWatcherImpl: _agentProviderWatcherImpl,
      focusProvider: focusProvider,
    );

    _activeAgentProposer.start(
      intelligenceServices: intelligenceServices,
      proposalListener: _proposalListener,
    );
  }

  /// Closes any open handles.
  void stop() {
    _proposalListener.stop();
    _activeAgentProposer.stop();
    _agentProviderWatcherBinding.close();
    _agentProvider.ctrl.close();
    _agentProviderWatcherImpl.link.ctrl.close();
  }
}

class _AgentProviderWatcherImpl extends AgentProviderWatcher {
  final LinkProxy link;
  final List<String> agents = <String>[];

  _AgentProviderWatcherImpl({this.link});

  @override
  void onUpdate(List<String> agentUrls) {
    agents
      ..clear()
      ..addAll(agentUrls);
    log.fine('agent urls: $agentUrls');
    String jsonString = json.encode(agentUrls);
    var jsonList = Uint8List.fromList(utf8.encode(jsonString));
    var data = fuchsia_mem.Buffer(
      vmo: new SizedVmo.fromUint8List(jsonList),
      size: jsonList.length,
    );
    link.set(null, data);
  }
}

class _ActiveAgentProposer {
  final QueryHandlerBinding _queryHandlerBinding = new QueryHandlerBinding();
  _QueryHandlerImpl _queryHandlerImpl;

  void start({
    IntelligenceServices intelligenceServices,
    ProposalListener proposalListener,
  }) {
    _queryHandlerImpl = new _QueryHandlerImpl(
      proposalListener: proposalListener,
    );
    intelligenceServices.registerQueryHandler(
      _queryHandlerBinding.wrap(
        _queryHandlerImpl,
      ),
    );
  }

  void stop() {
    _queryHandlerImpl.stop();
    _queryHandlerBinding.close();
  }
}

class _QueryHandlerImpl extends QueryHandler {
  final Set<ProposalListenerBinding> _bindings =
      new Set<ProposalListenerBinding>();

  final ProposalListener proposalListener;

  _QueryHandlerImpl({this.proposalListener});

  @override
  Future<Null> onQuery(
      UserInput query, void callback(QueryResponse response)) async {
    List<Proposal> proposals = <Proposal>[];

    if ((query.text?.toLowerCase()?.startsWith('act') ?? false) ||
        (query.text?.toLowerCase()?.startsWith('age') ?? false) ||
        (query.text?.toLowerCase()?.contains('agent') ?? false) ||
        (query.text?.toLowerCase()?.contains('active') ?? false)) {
      ProposalListenerBinding binding = new ProposalListenerBinding();
      _bindings.add(binding);
      proposals.add(await (ProposalBuilder(
        id: 'View Active Agents',
        headline: 'View Active Agents',
      )
            ..color = 0xFFA5A700
            ..addIconUrl('/system/data/sysui/AgentIcon.png')
            ..listener = binding.wrap(proposalListener))
          .build());
    }
    callback(new QueryResponse(proposals: proposals));
  }

  void stop() {
    for (ProposalListenerBinding binding in _bindings) {
      binding.close();
    }
  }
}

class _ProposalListener extends ProposalListener {
  final StoryProvider storyProvider;
  final FocusProvider focusProvider;
  final _AgentProviderWatcherImpl agentProviderWatcherImpl;
  StoryControllerProxy storyControllerProxy;

  _ProposalListener({
    this.storyProvider,
    this.focusProvider,
    this.agentProviderWatcherImpl,
  });

  @override
  void onProposalAccepted(String proposalId, String preloadedStoryId) {
    stop();

    storyProvider.createStoryWithInfo(
      'link_viewer',
      <StoryInfoExtraEntry>[
        const StoryInfoExtraEntry(key: 'color', value: '0xFFA5A700'),
      ],
      json.encode(
        <String, List<String>>{
          'Active Agents': agentProviderWatcherImpl.agents
        },
      ),
      (String storyId) {
        storyControllerProxy = new StoryControllerProxy();
        storyProvider.getController(
          storyId,
          storyControllerProxy.ctrl.request(),
        );
        storyControllerProxy.getInfo((StoryInfo info, StoryState state) {
          focusProvider.request(info.id);
          var linkPath = new LinkPath(modulePath: <String>[], linkName: 'root');
          storyControllerProxy.getLink(
              linkPath, agentProviderWatcherImpl.link.ctrl.request());
          storyControllerProxy?.ctrl?.close();
          storyControllerProxy = null;
        });
      },
    );
  }

  void stop() {
    storyControllerProxy?.ctrl?.close();
    storyControllerProxy = null;
  }
}
