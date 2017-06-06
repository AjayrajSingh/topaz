// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

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

  /// Retrieves the events
  Future<Null> _fetchEvents() async {
    try {
      _events = await Api.searchEventsByArtist(null, apiKey);
      if (_events != null) {
        _loadingStatus = LoadingStatus.completed;
      } else {
        _loadingStatus = LoadingStatus.failed;
      }
    } catch (error, stackTrace) {
      print(error);
      print(stackTrace);
      _loadingStatus = LoadingStatus.failed;
    }
    notifyListeners();
  }

  /// Mark the given [Event] as selected
  void selectEvent(Event event) {
    _selectedEvent = event;

    //TODO(dayang@): Create new EventPage Module using the presenter

    notifyListeners();
  }
}
