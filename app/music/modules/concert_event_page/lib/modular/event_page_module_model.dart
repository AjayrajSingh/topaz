// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:apps.maxwell.services.context/context_publisher.fidl.dart';
import 'package:apps.maxwell.services.user/intelligence_services.fidl.dart';
import 'package:concert_api/api.dart';
import 'package:concert_models/concert_models.dart';
import 'package:concert_widgets/concert_widgets.dart';
import 'package:lib.widgets/modular.dart';

/// The context topic for "focal entities"
const String _kFocalEntitiesTopic = 'focal_entities';

/// The Entity type for a music artist.
const String _kMusicArtistType = 'http://types.fuchsia.io/music/artist';

/// [ModuleModel] that manages the state of the Event Module.
class EventPageModuleModel extends ModuleModel {
  /// Constructor
  EventPageModuleModel({this.apiKey}) : super();

  /// API key for Songkick APIs
  final String apiKey;

  /// The event for this given module
  Event _event;

  /// Get the event
  Event get event => _event;

  LoadingStatus _loadingStatus = LoadingStatus.inProgress;

  /// Get the current loading status
  LoadingStatus get loadingStatus => _loadingStatus;

  /// Retrieves the full event based on the given ID
  Future<Null> fetchEvent(int eventId) async {
    try {
      _event = await Api.getEvent(eventId, apiKey);
      if (_event != null) {
        _loadingStatus = LoadingStatus.completed;
      } else {
        _loadingStatus = LoadingStatus.failed;
      }
    } catch (_) {
      _loadingStatus = LoadingStatus.failed;
    }

    // TODO (dayang@): Publish the "Location Context" as "Context Link" once
    // the API becomes available
    _publishArtistContext();
    notifyListeners();
  }

  /// Fetch the event whenever the eventId is updated in the link
  @override
  void onNotify(String json) {
    final dynamic doc = JSON.decode(json);
    if (doc is Map && doc['songkick:eventId'] is int) {
      fetchEvent(doc['songkick:eventId']);
    }
  }

  void _publishArtistContext() {
    ContextPublisherProxy publisher = new ContextPublisherProxy();
    IntelligenceServicesProxy intelligenceServices =
        new IntelligenceServicesProxy();
    moduleContext.getIntelligenceServices(intelligenceServices.ctrl.request());
    intelligenceServices.getContextPublisher(publisher.ctrl.request());

    if (event != null && event.performances.isNotEmpty) {
      if (event.performances.first.artist?.name != null) {
        publisher.publish(
          _kFocalEntitiesTopic,
          JSON.encode(
            <String, String>{
              '@type': _kMusicArtistType,
              'name': event.performances.first.artist.name,
            },
          ),
        );
      }
    }
    publisher.ctrl.close();
    intelligenceServices.ctrl.close();
  }
}
