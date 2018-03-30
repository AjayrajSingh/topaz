// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:concert_api/api.dart';
import 'package:concert_models/concert_models.dart';
import 'package:concert_widgets/concert_widgets.dart';
import 'package:flutter/widgets.dart' show ValueChanged;
import 'package:fuchsia.fidl.modular/modular.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.story.dart/story.dart';
import 'package:lib.widgets/modular.dart';

import 'event_selector.dart';

const String _kSelectorLabel = 'focused_stories_with_my_story_id';

/// [ModuleModel] that manages the state of the Event Module.
class EventListModuleModel extends ModuleModel {
  final EventSelector _eventSelector = new EventSelector();
  final ContextReaderProxy _contextReaderProxy = new ContextReaderProxy();
  final ContextListenerBinding _contextListenerBinding =
      new ContextListenerBinding();
  final IntelligenceServicesProxy _intelligenceServicesProxy =
      new IntelligenceServicesProxy();

  /// Constructor
  EventListModuleModel({this.apiKey}) : super();

  /// API key for Songkick APIs
  final String apiKey;

  final ModuleControllerProxy _eventPageModuleController =
      new ModuleControllerProxy();

  /// Link meant to be used by the event page module
  /// This link contains the ID of the event that is focused
  final LinkProxy _eventLink = new LinkProxy();
  final LinkWatcherBinding _eventLinkWatcherBinding = new LinkWatcherBinding();

  bool _startedEventModule = false;

  /// The current device mode
  String get deviceMode => _deviceMode;
  String _deviceMode;

  /// List of upcoming nearby events
  List<Event> get events =>
      _events != null ? new UnmodifiableListView<Event>(_events) : null;
  List<Event> _events = <Event>[];

  /// Get the current loading status
  LoadingStatus get loadingStatus => _loadingStatus;
  LoadingStatus _loadingStatus = LoadingStatus.inProgress;

  int _currentPageIndex = 0;

  /// Get the currently selected event
  Event get selectedEvent {
    if (events == null) {
      return null;
    } else {
      return _events.firstWhere(
        (Event event) => event.id == _selectedEventId,
        orElse: () => null,
      );
    }
  }

  int _selectedEventId;

  /// Retrieves the events
  Future<Null> _fetchEvents(String metroId) async {
    try {
      _events = await Api.searchEventsByArtist(
        apiKey: apiKey,
        metroId: metroId,
      );
      if (_events != null) {
        _loadingStatus = LoadingStatus.completed;
      } else {
        _loadingStatus = LoadingStatus.failed;
      }
    } on Exception catch (exception) {
      log.severe('Failed to Retrieve Concert Events', exception);
      _loadingStatus = LoadingStatus.failed;
    }
    notifyListeners();
  }

  /// Mark the given [Event] as selected
  void selectEvent(Event event) {
    Map<String, dynamic> data = <String, dynamic>{
      'songkick:eventId': event.id,
    };
    _eventLink.set(null, json.encode(data));
  }

  /// Call when the current event page changes.
  void onPageChanged(int currentPageIndex) {
    _currentPageIndex = currentPageIndex;
    _registerEventsWithEventSelector();
  }

  Future<Null> _onNotifyChild(String encoded) async {
    Map<String, dynamic> decoded = json.decode(encoded);
    if (decoded != null && decoded['songkick:eventId'] is int) {
      _selectedEventId = decoded['songkick:eventId'];

      // Start the Event Module if it hasn't been started
      if (!_startedEventModule) {
        moduleContext.startModuleInShellDeprecated(
          'event_module',
          'concert_event_page',
          'event_link',
          null, // incomingServices,
          _eventPageModuleController.ctrl.request(),
          const SurfaceRelation(
            arrangement: SurfaceArrangement.copresent,
            emphasis: 1.5,
            dependency: SurfaceDependency.dependent,
          ),
          true,
        );

        _startedEventModule = true;
      }

      _eventPageModuleController.focus();
      notifyListeners();
    }
  }

  @override
  void onReady(
    ModuleContext moduleContext,
    Link link,
  ) {
    super.onReady(moduleContext, link);

    moduleContext.getIntelligenceServices(
      _intelligenceServicesProxy.ctrl.request(),
    );

    _intelligenceServicesProxy.getContextReader(
      _contextReaderProxy.ctrl.request(),
    );

    moduleContext
      ..getStoryId((String storyId) {
        _contextReaderProxy.subscribe(
          new ContextQuery(selector: <ContextQueryEntry>[new ContextQueryEntry(
            key: _kSelectorLabel, value: new ContextSelector(
                type: ContextValueType.story,
                meta: new ContextMetadata(
                    story: new StoryMetadata(
                        id: storyId,
                        focused: new FocusedState(
                            state: FocusedStateState.focused)))),
          )]),
          _contextListenerBinding.wrap(
            new _ContextListenerImpl(
              onStoryInFocusChanged: (bool storyInFocus) {
                _eventSelector.storyInFocus = storyInFocus;
              },
            ),
          ),
        );
      })
      ..getLink('event_link', _eventLink.ctrl.request());
    _eventLink.watchAll(
      _eventLinkWatcherBinding.wrap(
        new LinkWatcherImpl(onNotify: _onNotifyChild),
      ),
    );
    _eventSelector.start(moduleContext);
  }

  @override
  Future<Null> onNotify(String encoded) async {
    try {
      dynamic doc = json.decode(encoded);
      dynamic uri = doc['view'];
      if (uri['host'] == 'www.songkick.com' &&
          uri['path segments'][0] == 'metro_areas') {
        // Songkick metro areas area specified as: id-name in the URL
        // We only want the ID before the first dash
        List<String> split = uri['path segments'][1].split('-');
        await _fetchEvents(split[0]);
      }
    } on Exception {
      return;
    }
  }

  @override
  void onStop() {
    _eventPageModuleController.ctrl.close();
    _eventLink?.ctrl?.close();
    _eventSelector.stop();
    _contextReaderProxy.ctrl.close();
    _contextListenerBinding.close();
    _intelligenceServicesProxy.ctrl.close();
  }

  @override
  void onDeviceMapChange(DeviceMapEntry entry) {
    Map<String, dynamic> profileMap = json.decode(entry.profile);
    if (_deviceMode != profileMap['mode']) {
      _deviceMode = profileMap['mode'];
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    _registerEventsWithEventSelector();
    super.notifyListeners();
  }

  void _registerEventsWithEventSelector() {
    // Deregister all old artists as selectable w.r.t. hotwords.
    _eventSelector.deregisterAllEvents();

    // Register all new artists as selectable w.r.t. hotwords.
    for (int i = 0; i < events.length; i++) {
      Event event = events[i];
      String artistName = event.performances.first.artist?.name;
      if (artistName != null) {
        _eventSelector.registerEvent(
          event.id.toString(),
          artistName,
          () => selectEvent(event),
        );
      }

      // For the events that are currently on screen, register events.
      // We assume three events per page.
      if (_currentPageIndex != null && _currentPageIndex == (i / 3).floor()) {
        if (i % 3 == 0) {
          _eventSelector
            ..registerEvent(
              'left',
              'left',
              () => selectEvent(event),
            )
            ..registerEvent(
              'first',
              'first',
              () => selectEvent(event),
            );
        } else if (i % 3 == 1) {
          _eventSelector
            ..registerEvent(
              'middle',
              'middle',
              () => selectEvent(event),
            )
            ..registerEvent(
              'second',
              'second',
              () => selectEvent(event),
            );
        } else if (i % 3 == 2) {
          _eventSelector
            ..registerEvent(
              'right',
              'right',
              () => selectEvent(event),
            )
            ..registerEvent(
              'third',
              'third',
              () => selectEvent(event),
            );
        }
      }
    }
  }
}

class _ContextListenerImpl extends ContextListener {
  final ValueChanged<bool> onStoryInFocusChanged;

  _ContextListenerImpl({this.onStoryInFocusChanged});

  @override
  Future<Null> onContextUpdate(ContextUpdate result) async {
    for (final ContextUpdateEntry entry in result.values) {
      if (entry.key != _kSelectorLabel) {
        continue;
      }

      if (entry.value.isEmpty) {
        onStoryInFocusChanged?.call(false);
      } else {
        onStoryInFocusChanged?.call(true);
      }
    }
  }
}
