// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_modular/fidl_async.dart'
    show
        AddMod,
        IntelligenceServicesProxy,
        ProposalPublisherProxy,
        QueryHandler,
        QueryHandlerBinding,
        QueryResponse,
        SetFocusState,
        StoryCommand,
        SurfaceRelation,
        UserInput;
import 'package:fuchsia_modular/module.dart';
import 'package:fuchsia_modular/proposal.dart';
import 'package:fuchsia_services/services.dart';

/// Proposes suggestions for queries matching http(s) prefix or web search.
class WebProposer extends QueryHandler {
  final _proposalPublisherProxy = ProposalPublisherProxy();
  final _queryHandlerBinding = QueryHandlerBinding();

  /// Starts the proposal process.
  void start() {
    final intelligenceServicesProxy = IntelligenceServicesProxy();
    StartupContext.fromStartupInfo()
        .incoming
        .connectToService(intelligenceServicesProxy);
    intelligenceServicesProxy
      ..getProposalPublisher(_proposalPublisherProxy.ctrl.request())
      ..registerQueryHandler(
        _queryHandlerBinding.wrap(this),
      );
    intelligenceServicesProxy.ctrl.close();
  }

  /// Stops the proposal process.
  void stop() {
    _proposalPublisherProxy.ctrl.close();
    _queryHandlerBinding.close();
  }

  @override
  Future<QueryResponse> onQuery(UserInput input) async {
    List<Proposal> proposals = <Proposal>[];
    String url = input.text;
    if (url != null && url.length >= 2) {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        proposals = await Future.wait([_createPackageProposal(url, url)]);
      } else if (!url.startsWith('fuchsia-pkg://')) {
        String search = 'https://www.google.com/search?q=${input.text}';
        proposals = await Future.wait([_createPackageProposal(search, url)]);
      }
    }

    return QueryResponse(proposals: proposals);
  }

  Future<Proposal> _createPackageProposal(String url, String query) async {
    final AddMod addMod = AddMod(
      intent: Intent(action: '', handler: url),
      surfaceParentModName: [],
      modName: ['module:web_view'],
      surfaceRelation: SurfaceRelation(),
    );
    return Proposal(
      id: url,
      headline: url == query ? 'open $url' : 'search for \'$query\'',
      confidence: url == query ? 0.9 : 0.1,
      details: query,
    )
      ..addStoryCommand(StoryCommand.withAddMod(addMod))
      ..addStoryCommand(
          StoryCommand.withSetFocusState(SetFocusState(focused: true)));
  }
}
