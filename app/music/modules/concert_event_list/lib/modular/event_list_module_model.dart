// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:apps.modular.services.module/module_controller.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:apps.modular.services.surface/surface.fidl.dart';
import 'package:concert_api/api.dart';
import 'package:concert_models/concert_models.dart';
import 'package:concert_widgets/concert_widgets.dart';
import 'package:lib.widgets/modular.dart';

/// [ModuleModel] that manages the state of the Event Module.
class EventListModuleModel extends ModuleModel {
  /// API key for Songkick APIs
  final String apiKey;

  List<Event> _events = <Event>[];

  Event _selectedEvent;

  LoadingStatus _loadingStatus = LoadingStatus.inProgress;

  final ModuleControllerProxy _eventPageModuleController =
      new ModuleControllerProxy();

  /// Link meant to be used by the event page module
  /// This link contains the ID of the event that is focused
  LinkProxy _eventLink;

  /// Constructor
  EventListModuleModel({this.apiKey}) : super() {
    _fetchEvents();
  }

  /// List of upcoming nearby events
  List<Event> get events =>
      _events != null ? new UnmodifiableListView<Event>(_events) : null;

  /// Get the current loading status
  LoadingStatus get loadingStatus => _loadingStatus;

  /// Get the currently selected event
  Event get selectedEvent => _selectedEvent;

  String get _selectedEventLinkData {
    if (_selectedEvent == null) {
      return '';
    } else {
      Map<String, dynamic> data = <String, dynamic>{
        'songkick:eventId': _selectedEvent.id,
      };
      return JSON.encode(data);
    }
  }

  /// Retrieves the events
  Future<Null> _fetchEvents() async {
    try {
      _events = await Api.searchEventsByArtist(null, apiKey);
      if (_events != null) {
        _loadingStatus = LoadingStatus.completed;
      } else {
        _loadingStatus = LoadingStatus.failed;
      }
    } catch (_) {
      _loadingStatus = LoadingStatus.failed;
    }
    notifyListeners();
  }

  /// Mark the given [Event] as selected
  void selectEvent(Event event) {
    _selectedEvent = event;

    if (_eventLink == null) {
      _eventLink = new LinkProxy();
      moduleContext.getLink('event_link', _eventLink.ctrl.request());
      _eventLink.set(<String>[], _selectedEventLinkData);

      // TODO(dayang@) : Preserve module/surface relationship when this story is
      // rehydrated by the framework
      // https://fuchsia.atlassian.net/browse/SO-482

      moduleContext.startModuleInShell(
        'event_module',
        'file:///system/apps/concert_event_page',
        'event_link',
        null, // outgoingServices,
        null, // incomingServices,
        _eventPageModuleController.ctrl.request(),
        new SurfaceRelation()
          ..arrangement = SurfaceArrangement.copresent
          ..emphasis = 1.5
          ..dependency = SurfaceDependency.dependent,
        true,
      );
    } else {
      _eventLink.set(<String>[], _selectedEventLinkData);
    }

    // Always focus on the EventPageModule surface in case it has been dismissed
    _eventPageModuleController.focus();
    notifyListeners();
  }

  @override
  void onStop() {
    _eventPageModuleController.ctrl.close();
    _eventLink?.ctrl?.close();
  }
}
