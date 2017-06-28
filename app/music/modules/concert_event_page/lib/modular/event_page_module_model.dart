// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:application.services/service_provider.fidl.dart';
import 'package:apps.maxwell.services.context/context_publisher.fidl.dart';
import 'package:apps.maxwell.services.user/intelligence_services.fidl.dart';
import 'package:apps.modular.services.module/module_context.fidl.dart';
import 'package:apps.modular.services.module/module_controller.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:apps.modular.services.surface/surface.fidl.dart';
import 'package:concert_api/api.dart';
import 'package:concert_models/concert_models.dart';
import 'package:concert_widgets/concert_widgets.dart';
import 'package:lib.widgets/modular.dart';
import 'package:web_view/web_view.dart' as web_view;

/// The context topic for "focal entities"
const String _kFocalEntitiesTopic = 'focal_entities';

/// The Entity type for a music artist.
const String _kMusicArtistType = 'http://types.fuchsia.io/music/artist';

/// The Entity type for a location
const String _kLocationType = 'http://types.fuchsia.io/location';

const String _kContextLinkName = 'location_context';

const String _kWebViewLinkName = 'web_view';

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

  final LinkProxy _contextLink = new LinkProxy();

  LinkProxy _webViewLink;

  final ModuleControllerProxy _webViewModuleController =
      new ModuleControllerProxy();

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

    _publishLocationContext();
    _publishArtistContext();
    notifyListeners();
  }

  @override
  void onReady(
    ModuleContext moduleContext,
    Link link,
    ServiceProvider incomingServices,
  ) {
    super.onReady(moduleContext, link, incomingServices);

    // Setup the Context Link
    moduleContext.getLink(_kContextLinkName, _contextLink.ctrl.request());
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

  void _publishLocationContext() {
    if (event != null && event.venue != null) {
      Map<String, dynamic> contextLinkData = <String, dynamic>{
        '@context': <String, dynamic>{
          'topic': _kFocalEntitiesTopic,
        },
        '@type': _kLocationType,
        'longitude': event.venue.longitude,
        'latitude': event.venue.latitude,
      };
      _contextLink.set(null, JSON.encode(contextLinkData));
    }
  }

  /// Opens web view module to purchase tickets
  void purchaseTicket() {
    if (event != null && event.url != null) {
      String linkData = JSON.encode(<String, Map<String, String>>{
        'view': <String, String>{'uri': event.url},
      });

      if (_webViewLink == null) {
        _webViewLink = new LinkProxy();
        moduleContext.getLink(_kWebViewLinkName, _webViewLink.ctrl.request());
        _webViewLink.set(null, linkData);
        moduleContext.startModuleInShell(
          'Purchase Web View',
          web_view.kWebViewURL,
          _kWebViewLinkName,
          null, // outgoingServices,
          null, // incomingServices,
          _webViewModuleController.ctrl.request(),
          new SurfaceRelation()..arrangement = SurfaceArrangement.sequential,
          true,
        );
      } else {
        _webViewLink.set(null, linkData);
      }
      _webViewModuleController.focus();
    }
  }
}
