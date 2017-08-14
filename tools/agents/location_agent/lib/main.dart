// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:application.lib.app.dart/app.dart';
import 'package:apps.maxwell.services.context/context_reader.fidl.dart';
import 'package:apps.maxwell.services.suggestion/proposal.fidl.dart';
import 'package:apps.maxwell.services.suggestion/proposal_publisher.fidl.dart';
import 'package:apps.maxwell.services.suggestion/suggestion_display.fidl.dart';
import 'package:apps.modular.services.surface/surface.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.logging/logging.dart';

/// The context topic for location
const String _kLocationTopic = '/story/focused/link/location';

/// The Entity type for a location
const String _kLocationType = 'http://types.fuchsia.io/location';

const String _kSuggestionIconUrl =
    'https://www.gstatic.com/images/icons/material/system/2x/directions_walk_googblue_48dp.png';

final ContextReaderProxy _contextReader = new ContextReaderProxy();
ContextListenerForTopicsImpl _contextListenerImpl;
final ProposalPublisherProxy _proposalPublisher = new ProposalPublisherProxy();
final ApplicationContext _context = new ApplicationContext.fromStartupInfo();

/// Location ContextListenerForTopics that makes a Location Module proposal given a
/// valid location Context Link
class ContextListenerForTopicsImpl extends ContextListenerForTopics {
  final ContextListenerForTopicsBinding _binding = new ContextListenerForTopicsBinding();

  /// Gets the [InterfaceHandle]
  ///
  /// The returned handle should only be used once.
  InterfaceHandle<ContextListenerForTopics> getHandle() => _binding.wrap(this);

  @override
  Future<Null> onUpdate(ContextUpdateForTopics result) async {
    if (!result.values.containsKey(_kLocationTopic)) {
      return;
    }

    dynamic data = JSON.decode(result.values[_kLocationTopic]);

    if (data is Map<String, dynamic> && _isValidLocationContextLink(data)) {
      Proposal proposal = new Proposal()
        ..id = 'Location Details'
        ..display = (new SuggestionDisplay()
          ..headline =
              'See current weather and travel details for this location'
          ..subheadline = ''
          ..details = ''
          ..color = 0xFFFF0080
          ..iconUrls = const <String>[_kSuggestionIconUrl]
          ..imageType = SuggestionImageType.other
          ..imageUrl = ''
          ..annoyance = AnnoyanceType.none)
        ..onSelected = <Action>[
          new Action()
            ..addModuleToStory = (new AddModuleToStory()
              ..linkName = data['@source']['link_name']
              ..storyId = data['@source']['story_id']
              ..moduleName = 'Location Details'
              ..modulePath = data['@source']['module_path']
              ..moduleUrl = 'location_details'
              ..surfaceRelation = (new SurfaceRelation()
                ..arrangement = SurfaceArrangement.copresent
                ..emphasis = 0.666
                ..dependency = SurfaceDependency.dependent))
        ];
      _proposalPublisher.propose(proposal);
    }
  }

  /// A valid location link must satisfy the following criteria:
  /// * @type must be 'http://types.fuchsia.io/location'.
  /// * Must have a @source field which contains the story ID, link name and
  ///   module path.
  /// * Must specify a latitude.
  /// * Must specify a longitude.
  bool _isValidLocationContextLink(Map<String, dynamic> data) {
    return data != null &&
        data['@type'] is String &&
        data['@type'] == _kLocationType &&
        data['@source'] is Map<String, dynamic> &&
        data['@source']['story_id'] is String &&
        data['@source']['link_name'] is String &&
        data['@source']['module_path'] is List<String> &&
        data['longitude'] is double &&
        data['latitude'] is double;
  }
}

void main(List<dynamic> args) {
  setupLogger(name: 'Location Agent');

  connectToService(_context.environmentServices, _contextReader.ctrl);
  connectToService(_context.environmentServices, _proposalPublisher.ctrl);

  ContextQueryForTopics query = new ContextQueryForTopics()
      ..topics = <String>[_kLocationTopic];
  _contextListenerImpl = new ContextListenerForTopicsImpl();
  _contextReader.subscribeToTopics(query, _contextListenerImpl.getHandle());
}
