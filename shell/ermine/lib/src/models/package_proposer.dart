// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

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
        SurfaceArrangement,
        SurfaceRelation,
        UserInput;
import 'package:fuchsia_modular/module.dart';
import 'package:fuchsia_modular/proposal.dart';
import 'package:fuchsia_services/services.dart';

/// Proposes suggestions for packages found on the system.
class PackageProposer extends QueryHandler {
  final _proposalPublisherProxy = ProposalPublisherProxy();
  final _queryHandlerBinding = QueryHandlerBinding();

  /// Holds the currently focused story id. Set by [AppModel].
  String focusedStoryId;

  /// Starts the proposal process.
  void start() {
    final intelligenceServicesProxy = IntelligenceServicesProxy();
    StartupContext.fromStartupInfo()
        .incoming
        .connectToService(intelligenceServicesProxy);
    intelligenceServicesProxy
      ..getProposalPublisher(_proposalPublisherProxy.ctrl.request())
      ..registerQueryHandler(_queryHandlerBinding.wrap(this));
    intelligenceServicesProxy.ctrl.close();
  }

  /// Stops the proposal process.
  void stop() {
    _proposalPublisherProxy.ctrl.close();
    _queryHandlerBinding.close();
  }

  @override
  Future<QueryResponse> onQuery(UserInput query) async {
    List<Proposal> proposals = <Proposal>[];

    if ((query.text?.length ?? 0) >= 2) {
      if (query.text.startsWith('fuchsia-pkg://')) {
        proposals.add(await _createPackageProposal(query.text, query.text));
      } else {
        final directory = Directory('/pkgfs/packages/');

        if (await directory.exists()) {
          proposals = await Future.wait(directory
              .listSync(followLinks: false)
              .map((FileSystemEntity fileSystemEntity) =>
                  Uri.parse(fileSystemEntity.path).pathSegments.last)
              .where((String package) => package.contains(query.text))
              .map((package) {
            return focusedStoryId == null
                ? [_createPackageProposal(package, query.text)]
                : [
                    _createPackageProposal(package, query.text),
                    _createPackageProposal(package, query.text, focusedStoryId)
                  ];
          }).expand((proposal) => proposal));
        }
      }
    }

    return QueryResponse(proposals: proposals);
  }

  Future<Proposal> _createPackageProposal(String package, String query,
      [String focusedStory]) async {
    final fullPackageName = package.startsWith('fuchsia-pkg://')
        ? package
        : 'fuchsia-pkg://fuchsia.com/$package#meta/$package.cmx';
    final addMod = AddMod(
      intent: Intent(action: '', handler: fullPackageName),
      surfaceParentModName: focusedStory == null ? [] : ['root'],
      modName: [focusedStory == null ? 'root' : fullPackageName],
      surfaceRelation: SurfaceRelation(
        arrangement: SurfaceArrangement.copresent,
      ),
    );

    return Proposal(
      id: focusedStory == null ? 'open_$package' : 'add_$package',
      storyName: focusedStory,
      headline: focusedStory == null ? 'open $package' : 'add $package',
      confidence:
          package == query ? 0.9 : package.startsWith(query) ? 0.7 : 0.5,
      details: package,
    )
      ..addStoryCommand(StoryCommand.withAddMod(addMod))
      ..addStoryCommand(
          StoryCommand.withSetFocusState(SetFocusState(focused: true)));
  }
}
