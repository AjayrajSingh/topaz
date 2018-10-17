// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io';

import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:lib.module_resolver.dart/intent_builder.dart';
import 'package:lib.proposal.dart/proposal.dart';

const String _kConfigFile =
    '/system/data/sysui/contextual_location_proposals.json';
const String _kDataConfigFile = '/data/contextual_location_proposals.json';
const String _kAskProposalsFile = '/system/data/sysui/ask_proposals.json';

const String _kLocationHomeWorkTopic = 'location/home_work';

const String _kLaunchEverythingProposalId = 'demo_all';

/// Ensure we don't exceed the max message size.
const int _kMaxProposals = 42;

/// Proposes suggestions for home and work locations.
class HomeWorkProposer {
  final ProposalPublisherProxy _proposalPublisherProxy =
      new ProposalPublisherProxy();
  final QueryHandlerBinding _queryHandlerBinding = new QueryHandlerBinding();
  final _ContextAwareProposer _contextAwareProposer =
      new _ContextAwareProposer();

  /// Starts the proposal process.
  void start(
    ContextReader contextReader,
    IntelligenceServices intelligenceServices,
  ) {
    intelligenceServices
        .getProposalPublisher(_proposalPublisherProxy.ctrl.request());
    _contextAwareProposer.start(contextReader, _proposalPublisherProxy);

    final List<Map<String, String>> askProposals = convert.json.decode(
      new File(_kAskProposalsFile).readAsStringSync(),
    );

    intelligenceServices.registerQueryHandler(
      _queryHandlerBinding
          .wrap(new _QueryHandlerImpl(askProposals: askProposals)),
    );
  }

  /// Cleans up any handles opened by [start].
  void stop() {
    _contextAwareProposer.stop();
    _proposalPublisherProxy.ctrl.close();
    _queryHandlerBinding.close();
  }
}

class _ContextAwareProposer {
  final ContextListenerBinding _contextListenerBinding =
      new ContextListenerBinding();

  Future<Null> start(
    ContextReader contextReader,
    ProposalPublisher proposalPublisher,
  ) async {
    final Map<String, List<Map<String, String>>> proposals =
        convert.json.decode(
      new File(_kConfigFile).readAsStringSync(),
    );

    File dataProposalFile = new File(_kDataConfigFile);

    final Map<String, List<Map<String, String>>> dataProposals =
        dataProposalFile.existsSync()
            ? convert.json.decode(
                dataProposalFile.readAsStringSync(),
              )
            : <String, List<Map<String, String>>>{};

    if (proposals.keys.contains('unknown')) {
      for (Map<String, String> proposal in proposals['unknown']) {
        proposalPublisher.propose(await _createProposal(proposal));
      }
    }

    if (dataProposals.keys.contains('unknown')) {
      for (Map<String, String> proposal in dataProposals['unknown']) {
        proposalPublisher.propose(await _createProposal(proposal));
      }
    }

    ContextQuery query = const ContextQuery(selector: const <ContextQueryEntry>[
      const ContextQueryEntry(
          key: _kLocationHomeWorkTopic,
          value: const ContextSelector(
              type: ContextValueType.entity,
              meta: const ContextMetadata(
                  entity:
                      const EntityMetadata(topic: _kLocationHomeWorkTopic))))
    ]);

    contextReader.subscribe(
      query,
      _contextListenerBinding.wrap(
        new _ContextListenerImpl(
          proposalPublisher: proposalPublisher,
          onTopicChanged: (String locationJson) async {
            final Map<String, String> json = convert.json.decode(locationJson);
            if (json['location']?.isEmpty ?? true) {
              return;
            }

            // Remove all proposals.
            for (List<Map<String, String>> proposalCategories
                in proposals.values) {
              for (Map<String, String> proposal in proposalCategories) {
                proposalPublisher.remove(proposal['id']);
              }
            }

            for (List<Map<String, String>> proposalCategories
                in dataProposals.values) {
              for (Map<String, String> proposal in proposalCategories) {
                proposalPublisher.remove(proposal['id']);
              }
            }

            // Add proposals for this location.
            if (proposals.keys.contains(json['location'])) {
              for (Map<String, String> proposal
                  in proposals[json['location']]) {
                proposalPublisher.propose(await _createProposal(proposal));
              }
            }

            if (dataProposals.keys.contains(json['location'])) {
              for (Map<String, String> proposal
                  in dataProposals[json['location']]) {
                proposalPublisher.propose(await _createProposal(proposal));
              }
            }
          },
        ),
      ),
    );
  }

  void stop() {
    _contextListenerBinding.close();
  }
}

class _ContextListenerImpl extends ContextListener {
  final ProposalPublisher proposalPublisher;
  final void Function(String topicValue) onTopicChanged;

  _ContextListenerImpl({this.proposalPublisher, this.onTopicChanged});

  @override
  void onContextUpdate(ContextUpdate result) {
    for (final ContextUpdateEntry entry in result.values) {
      if (entry.key != _kLocationHomeWorkTopic) {
        continue;
      }
      if (entry.value.isNotEmpty) {
        onTopicChanged(entry.value[0].content);
      }
    }
  }
}

class _QueryHandlerImpl extends QueryHandler {
  final List<Map<String, String>> askProposals;

  _QueryHandlerImpl({this.askProposals});

  @override
  Future<Null> onQuery(
      UserInput query, void callback(QueryResponse response)) async {
    List<Proposal> proposals = <Proposal>[];

    String queryText = query.text?.toLowerCase() ?? '';

    if (queryText.startsWith('demo') ?? false) {
      proposals
        ..addAll(await Future.wait(askProposals.map(_createProposal)))
        ..add(await _launchEverythingProposal);
    }

    if (queryText.contains('launch') || queryText.contains('bring up')) {
      if (queryText.contains('shader')) {
        proposals.add(
          await _createAppProposal(
            id: 'Launch Shader Toy',
            appUrl: 'shadertoy_client',
            headline: 'Launch Shader Toy',
            imageType: SuggestionImageType.other,
            imageUrl:
                'https://www.gstatic.com/images/icons/material/system/2x/web_asset_grey600_48dp.png',
            color: 0xFF4A78C0,
            confidence: 1.0,
          ),
        );
      } else if (queryText.contains('perspective')) {
        proposals.add(
          await _createAppProposal(
            id: 'Launch Perspective 3D demo',
            appUrl: 'perspective',
            headline: 'Launch Perspective 3D demo',
            imageType: SuggestionImageType.other,
            imageUrl: 'https://goo.gl/bi9jBa',
            color: 0xFF4A78C0,
            confidence: 1.0,
          ),
        );
      } else if (queryText.contains('infinite')) {
        proposals.add(
          await _createAppProposal(
            id: 'Launch Infinite Scroller',
            appUrl: 'infinite_scroller',
            headline: 'Launch Infinite Scroller',
            imageType: SuggestionImageType.other,
            imageUrl:
                'https://www.gstatic.com/images/icons/material/system/2x/web_asset_grey600_48dp.png',
            color: 0xFF4A78C0,
            confidence: 1.0,
          ),
        );
      } else if (queryText.contains('spinning')) {
        proposals.add(
          await _createAppProposal(
            id: 'Launch Spinning Cube',
            appUrl: 'spinning_cube',
            headline: 'Launch Spinning Cube',
            imageType: SuggestionImageType.other,
            imageUrl:
                'https://www.gstatic.com/images/icons/material/system/2x/web_asset_grey600_48dp.png',
            color: 0xFF4A78C0,
            confidence: 1.0,
          ),
        );
      } else if (queryText.contains('hotel')) {
        proposals.add(
          await _createAppProposal(
            id: 'Launch Hotel Confirmation',
            appUrl: 'hotel_confirmation',
            headline: 'Launch Hotel Confirmation',
            imageType: SuggestionImageType.other,
            imageUrl:
                'https://www.gstatic.com/images/icons/material/system/2x/web_asset_grey600_48dp.png',
            color: 0xFF4A78C0,
            confidence: 1.0,
          ),
        );
      } else if (queryText.contains('concert')) {
        proposals.add(
          await _createAppProposal(
            id: 'Launch Concert List',
            appUrl: 'concert_event_list',
            headline: 'Launch Concert List',
            imageType: SuggestionImageType.other,
            imageUrl:
                'https://www.gstatic.com/images/icons/material/system/2x/web_asset_grey600_48dp.png',
            color: 0xFF4A78C0,
            confidence: 1.0,
          ),
        );
      }
    }
    if ((queryText.startsWith('per') ?? false) ||
        (queryText.contains('3d') ?? false)) {
      proposals.add(
        await _createAppProposal(
          id: 'Launch Perspective 3D demo',
          appUrl: 'perspective',
          headline: 'Launch Perspective 3D demo',
          imageType: SuggestionImageType.other,
          imageUrl: 'https://goo.gl/bi9jBa',
          color: 0xFF4A78C0,
        ),
      );
    }

    if ((query.text?.length ?? 0) >= 2) {
      Future<Null> scanDirectory(Directory directory,
          {bool recursive = true}) async {
        if (!directory.existsSync()) {
          return;
        }
        Iterable<String> fsPaths = directory
            .listSync(recursive: recursive, followLinks: false)
            .map((FileSystemEntity fileSystemEntity) => fileSystemEntity.path)
            .where((String path) => path.contains(query.text));

        if (recursive) {
          fsPaths = fsPaths.where(FileSystemEntity.isFileSync);
        }

        for (String path in fsPaths) {
          String name = Uri.parse(path).pathSegments.last;
          String binName = Uri.parse(path).pathSegments.last;
          String iconUrl =
              'https://www.gstatic.com/images/icons/material/system/2x/web_asset_grey600_48dp.png';
          int color = 0xFF000000 + (name.hashCode % 0xFFFFFF);
          if (name.contains('youtube')) {
            iconUrl = '/system/data/sysui/youtube_96dp.png';
            color = 0xFFEC2F01;
          } else if (name.contains('music')) {
            iconUrl = '/system/data/sysui/music_96dp.png';
            color = 0xFF3E2723;
          } else if (name.contains('email')) {
            iconUrl = '/system/data/sysui/inbox_96dp.png';
            color = 0xFF4285F4;
          } else if (name.contains('chat')) {
            iconUrl = '/system/data/sysui/chat_96dp.png';
            color = 0xFF9C26B0;
          } else if (path.contains('youtube')) {
            iconUrl = '/system/data/sysui/youtube_96dp.png';
            color = 0xFFEC2F01;
          } else if (path.contains('music')) {
            iconUrl = '/system/data/sysui/music_96dp.png';
            color = 0xFF3E2723;
          } else if (path.contains('email')) {
            iconUrl = '/system/data/sysui/inbox_96dp.png';
            color = 0xFF4285F4;
          } else if (path.contains('chat')) {
            iconUrl = '/system/data/sysui/chat_96dp.png';
            color = 0xFF9C26B0;
          }

          proposals.add(
            await _createAppProposal(
              id: 'open $name',
              appUrl: binName,
              headline: 'Launch $name',
              // TODO(design): Find a better way to add indicators to the
              // suggestions about their provenance, lack of safety, etc. that
              // would be useful for developers but not distracting in demos
              // subheadline: '(This is potentially unsafe)',
              iconUrl: iconUrl,
              color: color,
            ),
          );

          if (proposals.length > _kMaxProposals) {
            break;
          }
        }
      }

      await Future.wait(<Future<Null>>[
        scanDirectory(new Directory('/pkgfs/packages/'), recursive: false),
        scanDirectory(new Directory('/system/bin/')),
        scanDirectory(new Directory('/system/pkgs/')),
      ]);
    }

    callback(new QueryResponse(proposals: proposals));
  }

  Future<Proposal> get _launchEverythingProposal async {
    var proposalBuilder = ProposalBuilder(
      id: _kLaunchEverythingProposalId,
      headline: 'Launch everything',
    )
      ..color = 0xFFFF0080
      ..commands = askProposals
          .map((Map<String, String> proposal) => new StoryCommand.withAddMod(
                new AddMod(
                  intent:
                      (new IntentBuilder.handler(proposal['module_url'] ?? '')
                            ..addParameter(null, proposal['module_data']))
                          .intent,
                  modName: ['root'],
                  surfaceRelation: const SurfaceRelation(),
                  surfaceParentModName: [],
                ),
              ))
          .toList();
    return proposalBuilder.build();
  }
}

Future<Proposal> _createProposal(Map<String, String> proposal) async {
  var intentBuilder = IntentBuilder.handler(proposal['module_url'] ?? '')
    ..addParameter(null, proposal['module_data']);

  var proposalBuilder = ProposalBuilder(
    id: proposal['id'],
    headline: proposal['headline'] ?? '',
  )
    ..subheadline = proposal['subheadline']
    ..color = (proposal['color'] != null && proposal['color'].isNotEmpty)
        ? (int.tryParse(proposal['color']) ?? 0xFFFF0080)
        : 0xFFFF0080
    ..iconUrls =
        proposal['icon_url'] == null ? null : <String>[proposal['icon_url']]
    ..imageUrl = proposal['image_url']
    ..imageType = 'person' == proposal['type']
        ? SuggestionImageType.person
        : SuggestionImageType.other
    ..addStoryCommand(new StoryCommand.withAddMod(new AddMod(
      intent: intentBuilder.intent,
      modName: ['root'],
      surfaceRelation: null,
      surfaceParentModName: [],
    )));

  return proposalBuilder.build();
}

Future<Proposal> _createAppProposal({
  String id,
  String appUrl,
  String headline,
  String subheadline,
  String imageUrl,
  String iconUrl,
  SuggestionImageType imageType = SuggestionImageType.other,
  int color,
  double confidence = 0.0,
  AnnoyanceType annoyanceType = AnnoyanceType.none,
}) async {
  var proposalBuilder = ProposalBuilder(id: id, headline: headline)
    ..confidence = confidence
    ..subheadline = subheadline
    ..color = color
    ..imageUrl = imageUrl
    ..imageType = imageType
    ..annoyanceType = annoyanceType
    ..addStoryCommand(new StoryCommand.withAddMod(new AddMod(
      intent: (new IntentBuilder.handler(appUrl)).intent,
      modName: ['root'],
      surfaceRelation: null,
      surfaceParentModName: [],
    )));
  return proposalBuilder.build();
}
