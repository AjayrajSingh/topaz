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

/// Proposes suggestions when no query is entered.
class DefaultProposer extends QueryHandler {
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
    if (input.text.isEmpty) {
      // Open settings.
      proposals = await Future.wait([_createPackageProposal('settings')]);
    }

    return QueryResponse(proposals: proposals);
  }

  Future<Proposal> _createPackageProposal(String package) async {
    final packageUrl = 'fuchsia-pkg://fuchsia.com/$package#meta/$package.cmx';
    final AddMod addMod = AddMod(
      intent: Intent(action: '', handler: packageUrl),
      surfaceParentModName: [],
      modName: [packageUrl],
      surfaceRelation: SurfaceRelation(),
    );
    return Proposal(
      id: 'open_$package',
      headline: 'open $package',
      confidence: 0.9,
      details: package,
    )
      ..addStoryCommand(StoryCommand.withAddMod(addMod))
      ..addStoryCommand(
          StoryCommand.withSetFocusState(SetFocusState(focused: true)));
  }
}
