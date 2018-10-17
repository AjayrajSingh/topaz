// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.app.dart/app.dart';
import 'package:lib.module_resolver.dart/intent_builder.dart';
import 'package:lib.proposal.dart/proposal.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';

final IntelligenceServicesProxy _intelligenceServices =
    new IntelligenceServicesProxy();
final QueryHandlerBinding _queryHandlerBinding = new QueryHandlerBinding();

void main(List<String> args) {
  final StartupContext context = new StartupContext.fromStartupInfo();
  connectToService(context.environmentServices, _intelligenceServices.ctrl);
  _intelligenceServices.registerQueryHandler(
    _queryHandlerBinding.wrap(new _QueryHandlerImpl()),
  );
  context.close();
}

class _QueryHandlerImpl extends QueryHandler {
  static final RegExp _urlSubPattern =
      new RegExp(r'\.[a-z]{2}|(?:\d{1,3}\.){3}\d{1,3}|localhost');
  static final RegExp _dashboardSubPattern = new RegExp(r'^das|^fuc|^bui|^sta');
  static const String _chatHeadline = 'Open Chat';
  static const String _emailHeadline = 'Open Email';
  static const String _youtubeHeadline = 'Open YouTube';
  static const String _terminalHeadline = 'Open Terminal';

  @override
  Future<Null> onQuery(
    UserInput query,
    void callback(QueryResponse response),
  ) async {
    List<Proposal> proposals = <Proposal>[];
    if (query.text?.contains(_urlSubPattern) ?? false) {
      final String url = query.text.startsWith('http')
          ? query.text
          : query.text.startsWith('localhost')
              ? 'http://${query.text}'
              : 'https://${query.text}';

      proposals.add(
        await _createProposal(
          id: 'launch web mod',
          appUrl: url,
          headline: 'Go to ${query.text}',
          color: 0xff8080ff,
        ),
      );
    }
    if (query.text?.contains(_dashboardSubPattern) ?? false) {
      proposals.add(
        await _createProposal(
          id: 'launch dashboard',
          appUrl: 'dashboard',
          headline: 'View the Fuchsia Dashboard',
          color: 0xFFFF0080, // Fuchsia
          imageUrl:
              'https://avatars2.githubusercontent.com/u/12826430?v=3&s=200',
        ),
      );
    }
    if ((query.text?.isNotEmpty ?? false) &&
        _chatHeadline.toLowerCase().contains(query.text.toLowerCase())) {
      proposals.add(
        await _createProposal(
          id: 'open chat',
          appUrl: 'chat_conversation_list',
          headline: _chatHeadline,
          color: 0xFF9C27B0, // Material Purple 500
        ),
      );
    }
    if ((query.text?.isNotEmpty ?? false) &&
        _emailHeadline.toLowerCase().contains(query.text.toLowerCase())) {
      proposals.add(
        await _createProposal(
          id: 'open email',
          appUrl: 'email/nav',
          headline: _emailHeadline,
          color: 0xFF4285F4,
        ),
      );
    }
    if ((query.text?.isNotEmpty ?? false) &&
        _youtubeHeadline.toLowerCase().contains(query.text.toLowerCase())) {
      proposals.add(
        await _createProposal(
          id: 'open youtube',
          appUrl: 'youtube_player',
          headline: _youtubeHeadline,
          color: 0xFFE52D27 /* YouTube red from color spec */,
        ),
      );
    }
    if ((query.text?.isNotEmpty ?? false) &&
        _terminalHeadline.toLowerCase().contains(query.text.toLowerCase())) {
      proposals.add(
        await _createProposal(
          id: 'open terminal',
          appUrl: 'term',
          headline: _terminalHeadline,
          color: 0xFFE52D27 /* YouTube red from color spec */,
        ),
      );
    }

    if (query.text?.startsWith('test s') ?? false) {
      proposals
        ..addAll(await Future.wait(_kDummyProposals))
        ..addAll(await Future.wait(_kDummyInterruptions));
    }

    callback(new QueryResponse(proposals: proposals));
  }
}

final List<Future<Proposal>> _kDummyProposals = <Future<Proposal>>[
  _createUniqueDummyProposal(
    headline: 'Headline only',
  ),
  _createUniqueDummyProposal(
    headline: 'Headline with a longer text string',
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline with a longer text string that needs more space plus some',
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline using an even longer text string that needs to wrap to a third line just like this',
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline using an even longer text string that needs to wrap to a third line and exceeds the three line limit by adding a few more words',
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline: 'With a sub-headline',
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline: 'With a longer sub-headline that wraps to two lines',
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline:
        'With a longer sub-headline that wraps to two lines and then a third line just like this',
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline:
        'With a longer sub-headline that needs to wrap to multiple lines exceeding the maximum available lines just like this one here',
  ),
  _createUniqueDummyProposal(
    headline: 'Headline with a longer text string that needs more space',
    subheadline:
        'With a longer sub-headline that wraps to two lines and then a third line just like this',
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline using an even longer text string that needs to wrap to a third line just like this',
    subheadline:
        'With a longer sub-headline that wraps to two lines and then a third line just like this',
  ),
  _createUniqueDummyProposal(
    headline: 'Headline only',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
  ),
  _createUniqueDummyProposal(
    headline: 'Headline with a longer text string',
    imageUrl: 'https://avatars2.githubusercontent.com/u/12826430?v=3&s=200',
  ),
  _createUniqueDummyProposal(
    headline: 'Headline with a longer text string needing more space',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline using an even longer text string that needs to wrap to a third line',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline using an even longer text string that needs to wrap to a third line and exceeds the three line limit',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline: 'With a sub-headline',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline: 'With a longer sub-headline that wraps to two lines',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline:
        'With a longer sub-headline that wraps to two lines and then a third line',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline:
        'With a longer sub-headline that needs to wrap to multiple lines exceeding the maximum available lines',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
  ),
  _createUniqueDummyProposal(
    headline: 'Headline with a longer text string needing more space',
    subheadline:
        'With a longer sub-headline that wraps to two lines and then a third line',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline using an even longer text string that needs to wrap to a third line',
    subheadline:
        'With a longer sub-headline that wraps to two lines and then a third line',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
  ),
  _createUniqueDummyProposal(
    headline: 'Headline only',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    imageType: SuggestionImageType.person,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline with a longer text string',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    imageType: SuggestionImageType.person,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline with a longer text string that needs more space',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    imageType: SuggestionImageType.person,
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline using an even longer text string that needs to wrap to a third line',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    imageType: SuggestionImageType.person,
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline using an even longer text string that needs to wrap to a third line and exceeds the three line limit',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    imageType: SuggestionImageType.person,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline: 'With a sub-headline',
    imageUrl: 'https://avatars2.githubusercontent.com/u/12826430?v=3&s=200',
    imageType: SuggestionImageType.person,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline: 'With a longer sub-headline that wraps to two lines',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    imageType: SuggestionImageType.person,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline:
        'With a longer sub-headline that wraps to two lines and then a third line',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    imageType: SuggestionImageType.person,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline:
        'With a longer sub-headline that needs to wrap to multiple lines exceeding the maximum available lines',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    imageType: SuggestionImageType.person,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline with a longer text string that needs more space',
    subheadline:
        'With a longer sub-headline that wraps to two lines and then a third line',
    imageUrl: 'https://avatars2.githubusercontent.com/u/12826430?v=3&s=200',
    imageType: SuggestionImageType.person,
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline using an even longer text string that needs to wrap to a third line',
    subheadline:
        'With a longer sub-headline that wraps to two lines and then a third line',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    imageType: SuggestionImageType.person,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline only',
    iconUrl: '/data/test.png',
  ),
  _createUniqueDummyProposal(
    headline: 'Headline with a longer text string',
    iconUrl: '/data/test.png',
  ),
  _createUniqueDummyProposal(
    headline: 'Headline with a longer text string that needs more space',
    iconUrl: '/data/test.png',
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline using an even longer text string that needs to wrap to a third line',
    iconUrl: '/data/test.png',
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline using an even longer text string that needs to wrap to a third line and exceeds the three line limit',
    iconUrl: '/data/test.png',
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline: 'With a sub-headline',
    iconUrl: '/data/test.png',
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline: 'With a longer sub-headline that wraps to two lines',
    iconUrl: '/data/test.png',
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline:
        'With a longer sub-headline that wraps to two lines and then a third line',
    iconUrl: '/data/test.png',
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline:
        'With a longer sub-headline that needs to wrap to multiple lines exceeding the maximum available lines',
    iconUrl: '/data/test.png',
  ),
  _createUniqueDummyProposal(
    headline: 'Headline with a longer text string that needs more space',
    subheadline:
        'With a longer sub-headline that wraps to two lines and then a third line',
    iconUrl: '/data/test.png',
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline using an even longer text string that needs to wrap to a third line',
    subheadline:
        'With a longer sub-headline that wraps to two lines and then a third line',
    iconUrl: '/data/test.png',
  ),
];

final List<Future<Proposal>> _kDummyInterruptions = <Future<Proposal>>[
  _createUniqueDummyProposal(
    headline: 'Headline only',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline with a longer text string',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline with a longer text string that needs more space plus some',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline using an even longer text string that needs to wrap to a third line just like this',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline using an even longer text string that needs to wrap to a third line and exceeds the three line limit by adding a few more words',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline: 'With a sub-headline',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline: 'With a longer sub-headline that wraps to two lines',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline:
        'With a longer sub-headline that wraps to two lines and then a third line just like this',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline:
        'With a longer sub-headline that needs to wrap to multiple lines exceeding the maximum available lines just like this one here',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline with a longer text string that needs more space',
    subheadline:
        'With a longer sub-headline that wraps to two lines and then a third line just like this',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline using an even longer text string that needs to wrap to a third line just like this',
    subheadline:
        'With a longer sub-headline that wraps to two lines and then a third line just like this',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline only',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline with a longer text string',
    imageUrl: 'https://avatars2.githubusercontent.com/u/12826430?v=3&s=200',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline with a longer text string needing more space',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline using an even longer text string that needs to wrap to a third line',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline using an even longer text string that needs to wrap to a third line and exceeds the three line limit',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline: 'With a sub-headline',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline: 'With a longer sub-headline that wraps to two lines',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline:
        'With a longer sub-headline that wraps to two lines and then a third line',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline:
        'With a longer sub-headline that needs to wrap to multiple lines exceeding the maximum available lines',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline with a longer text string needing more space',
    subheadline:
        'With a longer sub-headline that wraps to two lines and then a third line',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline using an even longer text string that needs to wrap to a third line',
    subheadline:
        'With a longer sub-headline that wraps to two lines and then a third line',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline only',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    imageType: SuggestionImageType.person,
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline with a longer text string',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    imageType: SuggestionImageType.person,
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline with a longer text string that needs more space',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    imageType: SuggestionImageType.person,
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline using an even longer text string that needs to wrap to a third line',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    imageType: SuggestionImageType.person,
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline using an even longer text string that needs to wrap to a third line and exceeds the three line limit',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    imageType: SuggestionImageType.person,
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline: 'With a sub-headline',
    imageUrl: 'https://avatars2.githubusercontent.com/u/12826430?v=3&s=200',
    imageType: SuggestionImageType.person,
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline: 'With a longer sub-headline that wraps to two lines',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    imageType: SuggestionImageType.person,
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline:
        'With a longer sub-headline that wraps to two lines and then a third line',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    imageType: SuggestionImageType.person,
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline:
        'With a longer sub-headline that needs to wrap to multiple lines exceeding the maximum available lines',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    imageType: SuggestionImageType.person,
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline with a longer text string that needs more space',
    subheadline:
        'With a longer sub-headline that wraps to two lines and then a third line',
    imageUrl: 'https://avatars2.githubusercontent.com/u/12826430?v=3&s=200',
    imageType: SuggestionImageType.person,
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline using an even longer text string that needs to wrap to a third line',
    subheadline:
        'With a longer sub-headline that wraps to two lines and then a third line',
    imageUrl: 'https://i.redd.it/qh713wbo4r8y.jpg',
    imageType: SuggestionImageType.person,
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline only',
    iconUrl: '/data/test.png',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline with a longer text string',
    iconUrl: '/data/test.png',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline with a longer text string that needs more space',
    iconUrl: '/data/test.png',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline using an even longer text string that needs to wrap to a third line',
    iconUrl: '/data/test.png',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline using an even longer text string that needs to wrap to a third line and exceeds the three line limit',
    iconUrl: '/data/test.png',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline: 'With a sub-headline',
    iconUrl: '/data/test.png',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline: 'With a longer sub-headline that wraps to two lines',
    iconUrl: '/data/test.png',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline:
        'With a longer sub-headline that wraps to two lines and then a third line',
    iconUrl: '/data/test.png',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline small',
    subheadline:
        'With a longer sub-headline that needs to wrap to multiple lines exceeding the maximum available lines',
    iconUrl: '/data/test.png',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline: 'Headline with a longer text string that needs more space',
    subheadline:
        'With a longer sub-headline that wraps to two lines and then a third line',
    iconUrl: '/data/test.png',
    annoyanceType: AnnoyanceType.interrupt,
  ),
  _createUniqueDummyProposal(
    headline:
        'Headline using an even longer text string that needs to wrap to a third line',
    subheadline:
        'With a longer sub-headline that wraps to two lines and then a third line',
    iconUrl: '/data/test.png',
    annoyanceType: AnnoyanceType.interrupt,
  ),
];
int _id = 0;
Future<Proposal> _createUniqueDummyProposal({
  String headline,
  String subheadline,
  String iconUrl,
  String imageUrl,
  SuggestionImageType imageType = SuggestionImageType.other,
  AnnoyanceType annoyanceType = AnnoyanceType.none,
}) async =>
    _createProposal(
      id: 'dummy ${_id++}',
      appUrl: 'file:///foo/bar',
      headline: headline,
      subheadline: subheadline,
      color: 0xFF000000,
      iconUrl: iconUrl,
      imageType: imageType,
      imageUrl: imageUrl,
      annoyanceType: annoyanceType,
    );

Future<Proposal> _createProposal({
  String id,
  String appUrl,
  String headline,
  String subheadline,
  String imageUrl,
  String initialData,
  SuggestionImageType imageType = SuggestionImageType.other,
  String iconUrl,
  int color,
  AnnoyanceType annoyanceType = AnnoyanceType.none,
}) async {
  var intentBuilder = IntentBuilder.handler(appUrl)
    ..addParameter(null, initialData);
  var proposalBuilder = ProposalBuilder(
    id: id,
    headline: headline,
  )
    ..subheadline = subheadline
    ..color = color
    ..iconUrls = iconUrl == null ? null : <String>[iconUrl]
    ..imageUrl = imageUrl
    ..imageType = imageType
    ..annoyanceType = annoyanceType
    ..addStoryCommand(StoryCommand.withAddMod(new AddMod(
      intent: intentBuilder.intent,
      modName: ['root'],
      surfaceParentModName: [],
      surfaceRelation: const SurfaceRelation(),
    )));

  return proposalBuilder.build();
}
