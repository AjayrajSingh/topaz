// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' as convert;
import 'dart:io';

import 'package:lib.context.fidl/context_reader.fidl.dart';
import 'package:lib.context.fidl/metadata.fidl.dart';
import 'package:lib.context.fidl/value_type.fidl.dart';
import 'package:lib.suggestion.fidl/proposal.fidl.dart';
import 'package:lib.suggestion.fidl/proposal_publisher.fidl.dart';
import 'package:lib.suggestion.fidl/query_handler.fidl.dart';
import 'package:lib.suggestion.fidl/suggestion_display.fidl.dart';
import 'package:lib.suggestion.fidl/user_input.fidl.dart';
import 'package:lib.user_intelligence.fidl/intelligence_services.fidl.dart';

const String _kConfigFile =
    '/system/data/sysui/contextual_location_proposals.json';
const String _kDataConfigFile = '/data/contextual_location_proposals.json';
const String _kAskProposalsFile = '/system/data/sysui/ask_proposals.json';

const String _kLocationHomeWorkTopic = 'location/home_work';

const String _kLaunchEverythingProposalId = 'demo_all';

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

    final List<Map<String, String>> askProposals = convert.JSON.decode(
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

  void start(
    ContextReader contextReader,
    ProposalPublisher proposalPublisher,
  ) {
    final Map<String, List<Map<String, String>>> proposals =
        convert.JSON.decode(
      new File(_kConfigFile).readAsStringSync(),
    );

    File dataProposalFile = new File(_kDataConfigFile);

    final Map<String, List<Map<String, String>>> dataProposals =
        dataProposalFile.existsSync()
            ? convert.JSON.decode(
                dataProposalFile.readAsStringSync(),
              )
            : <String, List<Map<String, String>>>{};

    if (proposals.keys.contains('unknown')) {
      for (Map<String, String> proposal in proposals['unknown']) {
        proposalPublisher.propose(_createProposal(proposal));
      }
    }

    if (dataProposals.keys.contains('unknown')) {
      for (Map<String, String> proposal in dataProposals['unknown']) {
        proposalPublisher.propose(_createProposal(proposal));
      }
    }

    ContextSelector selector = new ContextSelector()
      ..type = ContextValueType.entity
      ..meta = new ContextMetadata();
    selector.meta.entity = new EntityMetadata()
      ..topic = _kLocationHomeWorkTopic;
    ContextQuery query = new ContextQuery()
      ..selector = <String, ContextSelector>{_kLocationHomeWorkTopic: selector};

    contextReader.subscribe(
      query,
      _contextListenerBinding.wrap(
        new _ContextListenerImpl(
          proposalPublisher: proposalPublisher,
          onTopicChanged: (String locationJson) {
            final Map<String, String> json = convert.JSON.decode(locationJson);
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
                proposalPublisher.propose(_createProposal(proposal));
              }
            }

            if (dataProposals.keys.contains(json['location'])) {
              for (Map<String, String> proposal
                  in dataProposals[json['location']]) {
                proposalPublisher.propose(_createProposal(proposal));
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

typedef void _OnTopicChanged(String topicValue);

class _ContextListenerImpl extends ContextListener {
  final ProposalPublisher proposalPublisher;
  final _OnTopicChanged onTopicChanged;

  _ContextListenerImpl({this.proposalPublisher, this.onTopicChanged});

  @override
  void onContextUpdate(ContextUpdate result) {
    if (result.values[_kLocationHomeWorkTopic].isNotEmpty) {
      onTopicChanged(result.values[_kLocationHomeWorkTopic][0].content);
    }
  }
}

class _QueryHandlerImpl extends QueryHandler {
  final List<Map<String, String>> askProposals;

  _QueryHandlerImpl({this.askProposals});

  @override
  void onQuery(UserInput query, void callback(QueryResponse response)) {
    List<Proposal> proposals = <Proposal>[];

    String queryText = query.text?.toLowerCase() ?? '';

    if (queryText.startsWith('demo') ?? false) {
      proposals
        ..addAll(askProposals.map(_createProposal))
        ..add(_launchEverythingProposal);
    }

    if (queryText.contains('launch') || queryText.contains('bring up')) {
      if (queryText.contains('shader')) {
        proposals.add(
          _createAppProposal(
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
          _createAppProposal(
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
          _createAppProposal(
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
          _createAppProposal(
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
      } else if (queryText.contains('video')) {
        proposals.add(
          _createAppProposal(
            id: 'Launch Video',
            appUrl: 'video',
            headline: 'Launch Video',
            imageType: SuggestionImageType.other,
            imageUrl:
                'https://www.gstatic.com/images/icons/material/system/2x/web_asset_grey600_48dp.png',
            color: 0xFF4A78C0,
            confidence: 1.0,
          ),
        );
      } else if (queryText.contains('hotel')) {
        proposals.add(
          _createAppProposal(
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
          _createAppProposal(
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
        _createAppProposal(
          id: 'Launch Perspective 3D demo',
          appUrl: 'perspective',
          headline: 'Launch Perspective 3D demo',
          imageType: SuggestionImageType.other,
          imageUrl: 'https://goo.gl/bi9jBa',
          color: 0xFF4A78C0,
        ),
      );
    }

    if ((query.text?.length ?? 0) >= 4) {
      void scanDirectory(Directory directory) {
        for (String path in directory
            .listSync(recursive: true, followLinks: false)
            .map((FileSystemEntity fileSystemEntity) => fileSystemEntity.path)
            .where((String path) => path.contains(query.text))
            .where(FileSystemEntity.isFileSync)) {
          String name = Uri.parse(path).pathSegments.last;
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
            _createAppProposal(
              id: 'open $name',
              appUrl: 'file://$path',
              headline: 'Launch $name',
              // TODO(design): Find a better way to add indicators to the
              // suggestions about their provenance, lack of safety, etc. that
              // would be useful for developers but not distracting in demos
              // subheadline: '(This is potentially unsafe)',
              iconUrls: <String>[iconUrl],
              color: color,
            ),
          );
        }
      }

      scanDirectory(new Directory('/system/apps/'));
      scanDirectory(new Directory('/system/bin/'));
      scanDirectory(new Directory('/system/pkgs/'));
    }

    callback(new QueryResponse()..proposals = proposals);
  }

  Proposal get _launchEverythingProposal => new Proposal()
    ..id = _kLaunchEverythingProposalId
    ..display = (new SuggestionDisplay()
      ..headline = 'Launch everything'
      ..subheadline = ''
      ..details = ''
      ..color = 0xFFFF0080
      ..iconUrls = const <String>[]
      ..imageType = SuggestionImageType.other
      ..imageUrl = ''
      ..annoyance = AnnoyanceType.none)
    ..onSelected = askProposals
        .map(
          (Map<String, String> proposal) => new Action()
            ..createStory = (new CreateStory()
              ..moduleId = proposal['module_url'] ?? ''
              ..initialData = proposal['module_data']),
        )
        .toList();
}

Proposal _createProposal(Map<String, String> proposal) => new Proposal()
  ..id = proposal['id']
  ..display = (new SuggestionDisplay()
    ..headline = proposal['headline'] ?? ''
    ..subheadline = proposal['subheadline'] ?? ''
    ..details = ''
    ..color = (proposal['color'] != null && proposal['color'].isNotEmpty)
        ? int.parse(proposal['color'], onError: (_) => 0xFFFF0080)
        : 0xFFFF0080
    ..iconUrls = proposal['icon_url'] != null
        ? <String>[proposal['icon_url']]
        : const <String>[]
    ..imageType = 'person' == proposal['type']
        ? SuggestionImageType.person
        : SuggestionImageType.other
    ..imageUrl = proposal['image_url'] ?? ''
    ..annoyance = AnnoyanceType.none)
  ..onSelected = <Action>[
    new Action()
      ..createStory = (new CreateStory()
        ..moduleId = proposal['module_url'] ?? ''
        ..initialData = proposal['module_data'])
  ];

Proposal _createAppProposal({
  String id,
  String appUrl,
  String headline,
  String subheadline,
  String imageUrl: '',
  SuggestionImageType imageType: SuggestionImageType.other,
  List<String> iconUrls = const <String>[],
  int color,
  double confidence: 0.0,
  AnnoyanceType annoyanceType: AnnoyanceType.none,
}) =>
    new Proposal()
      ..id = id
      ..confidence = confidence
      ..display = (new SuggestionDisplay()
        ..headline = headline
        ..subheadline = subheadline ?? ''
        ..details = ''
        ..color = color
        ..iconUrls = iconUrls
        ..imageType = imageType
        ..imageUrl = imageUrl
        ..annoyance = annoyanceType)
      ..onSelected = <Action>[
        new Action()..createStory = (new CreateStory()..moduleId = appUrl)
      ];
