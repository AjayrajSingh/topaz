// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:armadillo/common.dart';
import 'package:armadillo/next.dart';
import 'package:armadillo/now.dart';
import 'package:armadillo/overview.dart';
import 'package:armadillo/recent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fuchsia.fidl.modular/modular.dart';
import 'package:fuchsia.fidl.power_manager/power_manager.dart';
import 'package:fuchsia.fidl.time_zone/time_zone.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.media.dart/audio_policy.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/modular.dart';
import 'package:lib.widgets/widgets.dart';
import 'package:sysui_widgets/default_bundle.dart';

import 'armadillo_user_shell_model.dart';
import 'audio_policy_volume_model.dart';
import 'context_provider_context_model.dart';
import 'focus_request_watcher_impl.dart';
import 'focused_stories_tracker.dart';
import 'hit_test_model.dart';
import 'initial_focus_setter.dart';
import 'maxwell_voice_model.dart';
import 'power_manager_power_model.dart';
import 'story_provider_story_generator.dart';
import 'suggestion_provider_suggestion_model.dart';
import 'user_logoutter.dart';

/// Set to true to enable the performance overlay.
const bool _kShowPerformanceOverlay = false;

/// Set to true to enable dumping of all errors, not just the first one.
const bool _kDumpAllErrors = false;

Future<Null> main() async {
  runApp(
    buildArmadilloUserShell(
      sizeModel: new SizeModel(),
      conductorModel: new ConductorModel(),
      applicationContext: new ApplicationContext.fromStartupInfo(),
    ),
  );
}

/// Builds the armadillo user shell.
Widget buildArmadilloUserShell({
  String logName: 'armadillo',
  @required SizeModel sizeModel,
  @required ConductorModel conductorModel,
  @required ApplicationContext applicationContext,
}) {
  setupLogger(name: logName);

  if (_kDumpAllErrors) {
    FlutterError.onError =
        (FlutterErrorDetails details) => FlutterError.dumpErrorToConsole(
              details,
              forceReport: true,
            );
  }

  HitTestModel hitTestModel = new HitTestModel();
  InitialFocusSetter initialFocusSetter = new InitialFocusSetter();

  StoryProviderStoryGenerator storyProviderStoryGenerator =
      new StoryProviderStoryGenerator(
    onStoriesFirstAvailable: initialFocusSetter.onStoriesFirstAvailable,
    onStoryClusterFocusStarted: conductorModel.onStoryClusterFocusStarted,
    onStoryClusterFocusCompleted: conductorModel.onStoryClusterFocusCompleted,
  );
  StoryClusterDragStateModel storyClusterDragStateModel =
      new StoryClusterDragStateModel();
  StoryRearrangementScrimModel storyRearrangementScrimModel =
      new StoryRearrangementScrimModel();
  storyClusterDragStateModel
    ..addListener(
      () => storyRearrangementScrimModel.onDragAcceptableStateChanged(
            isAcceptable: storyClusterDragStateModel.isAccepting,
          ),
    )
    ..addListener(
      () => storyProviderStoryGenerator.onDraggingChanged(
            dragging: storyClusterDragStateModel.isDragging,
          ),
    );
  StoryDragTransitionModel storyDragTransitionModel =
      new StoryDragTransitionModel();
  storyClusterDragStateModel.addListener(
    () => storyDragTransitionModel.onDragStateChanged(
          isDragging: storyClusterDragStateModel.isDragging,
        ),
  );

  UserLogoutter userLogoutter = new UserLogoutter();
  SuggestionProviderSuggestionModel suggestionProviderSuggestionModel =
      new SuggestionProviderSuggestionModel(
    hitTestModel: hitTestModel,
    onInterruption: conductorModel.nextBuilder.onInterruption,
  );
  conductorModel.nextBuilder
    ..onSuggestionsOverlayChanged = ((bool active) =>
        hitTestModel.onSuggestionsOverlayChanged(active: active))
    ..onInterruptionDismissed =
        suggestionProviderSuggestionModel.onInterruptionDismissal;

  FocusedStoriesTracker focusedStoriesTracker = new FocusedStoriesTracker();

  StoryModel storyModel = new StoryModel(
    onFocusChanged: focusedStoriesTracker.onStoryClusterFocusChanged,
    onDeleteStoryCluster: storyProviderStoryGenerator.onDeleteStoryCluster,
    onStoryClusterAdded: storyProviderStoryGenerator.onStoryClusterAdded,
    onStoryClusterRemoved: storyProviderStoryGenerator.onStoryClusterRemoved,
  );

  storyModel.addListener(() => focusedStoriesTracker
      .onStoryClusterListChanged(storyModel.storyClusters));

  storyProviderStoryGenerator.addListener(
    () => storyModel.onStoryClustersChanged(
          storyProviderStoryGenerator.storyClusters,
        ),
  );

  initialFocusSetter.storyFocuser = conductorModel.focusStory;

  FocusRequestWatcherImpl focusRequestWatcher = new FocusRequestWatcherImpl(
    onFocusRequest: (String storyId) {
      // If we don't know about the story that we've been asked to focus, update
      // the story list first.
      if (!storyProviderStoryGenerator.containsStory(storyId)) {
        log.info(
          'Story $storyId isn\'t in the list, querying story provider...',
        );
        storyProviderStoryGenerator.update(
          () => conductorModel.focusStory(storyId),
        );
      } else {
        conductorModel.focusStory(storyId);
      }
    },
  );

  TimezoneProxy timezoneProxy = new TimezoneProxy();
  connectToService(
      applicationContext.environmentServices, timezoneProxy.ctrl);

  ContextProviderContextModel contextProviderContextModel =
      new ContextProviderContextModel(
    timezone: timezoneProxy,
  );

  DeviceMapProxy deviceMapProxy = new DeviceMapProxy();
  DeviceMapWatcherBinding deviceMapWatcher = new DeviceMapWatcherBinding();

  connectToService(applicationContext.environmentServices, deviceMapProxy.ctrl);

  deviceMapProxy.watchDeviceMap(
    deviceMapWatcher.wrap(
      new _DeviceMapWatcherImpl(
        onProfileChanged: contextProviderContextModel.onDeviceProfileChanged,
      ),
    ),
  );

  AudioPolicy audioPolicy = new AudioPolicy(
    applicationContext.environmentServices,
  );
  VolumeModel volumeModel = new AudioPolicyVolumeModel(
    audioPolicy: audioPolicy,
  )..level = 1.0;

  PowerManagerProxy powerManagerProxy = new PowerManagerProxy();
  connectToService(
    applicationContext.environmentServices,
    powerManagerProxy.ctrl,
  );

  PowerManagerPowerModel powerModel = new PowerManagerPowerModel(
    powerManager: powerManagerProxy,
  );

  MaxwellVoiceModel voiceModel = new MaxwellVoiceModel();

  ArmadilloUserShellModel armadilloUserShellModel = new ArmadilloUserShellModel(
    applicationContext: applicationContext,
    storyProviderStoryGenerator: storyProviderStoryGenerator,
    suggestionProviderSuggestionModel: suggestionProviderSuggestionModel,
    maxwellVoiceModel: voiceModel,
    focusRequestWatcher: focusRequestWatcher,
    initialFocusSetter: initialFocusSetter,
    userLogoutter: userLogoutter,
    onContextUpdated: contextProviderContextModel.onContextUpdated,
    onUserUpdated: contextProviderContextModel.onUserUpdated,
    contextTopics: ContextProviderContextModel.topics,
    onUserShellStopped: () {
      audioPolicy.dispose();
      powerManagerProxy.ctrl.close();
      powerModel.close();
      deviceMapProxy.ctrl.close();
      deviceMapWatcher.close();
      timezoneProxy.ctrl.close();
    },
    onWallpaperChosen: contextProviderContextModel.onWallpaperChosen,
  );

  focusedStoriesTracker.addListener(() {
    armadilloUserShellModel
      ..focusController.set(
        focusedStoriesTracker.focusedStoryId,
      )
      ..visibleStoriesController.set(
        focusedStoriesTracker.focusedStoryIds,
      );
    hitTestModel.onVisibleStoriesChanged(
      focusedStoriesTracker.focusedStoryIds,
    );
    if (focusedStoriesTracker.focusedStoryId == null) {
      conductorModel.goToOrigin();
    }
  });

  QuickSettingsProgressModel quickSettingsProgressModel =
      new QuickSettingsProgressModel();

  PeekModel peekModel = new PeekModel();
  storyClusterDragStateModel.addListener(
    () => peekModel.onStoryClusterDragStateModelChanged(
          storyClusterDragStateModel,
        ),
  );
  quickSettingsProgressModel.addListener(
    () => peekModel.onQuickSettingsProgressChanged(
          quickSettingsProgressModel.value,
        ),
  );

  conductorModel.nowBuilder
    ..onLogoutSelected = userLogoutter.logout
    ..onUserContextTapped = armadilloUserShellModel.onUserContextTapped
    ..onQuickSettingsOverlayChanged = (bool active) =>
        hitTestModel.onQuickSettingsOverlayChanged(active: active);

  Conductor conductor = conductorModel.build();

  DebugModel debugModel = new DebugModel();
  PanelResizingModel panelResizingModel = new PanelResizingModel();

  sizeModel
    ..addListener(
      () => storyModel.updateLayouts(
            new Size(
              sizeModel.storySize.width,
              sizeModel.storySize.height - SizeModel.kStoryBarMaximizedHeight,
            ),
          ),
    )
    ..screenSize = ui.window.physicalSize / ui.window.devicePixelRatio;

  Widget app = new ScopedModel<StoryDragTransitionModel>(
    model: storyDragTransitionModel,
    child: new ScopedModel<UserShellModel>(
      model: armadilloUserShellModel,
      child: _buildApp(
        storyModel: storyModel,
        storyProviderStoryGenerator: storyProviderStoryGenerator,
        debugModel: debugModel,
        armadillo: new Armadillo(
          scopedModelBuilders: <WrapperBuilder>[
            (_, Widget child) => new ScopedModel<ConductorModel>(
                  model: conductorModel,
                  child: child,
                ),
            (_, Widget child) => new ScopedModel<PowerModel>(
                  model: powerModel,
                  child: child,
                ),
            (_, Widget child) => new ScopedModel<VolumeModel>(
                  model: volumeModel,
                  child: child,
                ),
            (_, Widget child) => new ScopedModel<ContextModel>(
                  model: contextProviderContextModel,
                  child: child,
                ),
            (_, Widget child) => new ScopedModel<StoryModel>(
                  model: storyModel,
                  child: child,
                ),
            (_, Widget child) => new ScopedModel<SuggestionModel>(
                  model: suggestionProviderSuggestionModel,
                  child: child,
                ),
            (_, Widget child) => new ScopedModel<VoiceModel>(
                  model: voiceModel,
                  child: child,
                ),
            (_, Widget child) => new ScopedModel<QuickSettingsProgressModel>(
                  model: quickSettingsProgressModel,
                  child: child,
                ),
            (_, Widget child) => new ScopedModel<StoryClusterDragStateModel>(
                  model: storyClusterDragStateModel,
                  child: child,
                ),
            (_, Widget child) => new ScopedModel<StoryRearrangementScrimModel>(
                  model: storyRearrangementScrimModel,
                  child: child,
                ),
            (_, Widget child) => new ScopedModel<DebugModel>(
                  model: debugModel,
                  child: child,
                ),
            (_, Widget child) => new ScopedModel<PanelResizingModel>(
                  model: panelResizingModel,
                  child: child,
                ),
            (_, Widget child) => new ScopedModel<SizeModel>(
                  model: sizeModel,
                  child: child,
                ),
            (_, Widget child) => new ScopedModel<PeekModel>(
                  model: peekModel,
                  child: child,
                ),
          ],
          conductor: conductor,
        ),
        hitTestModel: hitTestModel,
      ),
    ),
  );

  UserShellWidget<ArmadilloUserShellModel> userShellWidget =
      new UserShellWidget<ArmadilloUserShellModel>(
    applicationContext: applicationContext,
    userShellModel: armadilloUserShellModel,
    child:
        _kShowPerformanceOverlay ? _buildPerformanceOverlay(child: app) : app,
  )..advertise();

  contextProviderContextModel.load();

  return new WindowMediaQuery(
    onWindowMetricsChanged: () {
      sizeModel.screenSize =
          ui.window.physicalSize / ui.window.devicePixelRatio;
    },
    child: userShellWidget,
  );
}

Widget _buildApp({
  StoryModel storyModel,
  StoryProviderStoryGenerator storyProviderStoryGenerator,
  DebugModel debugModel,
  Armadillo armadillo,
  HitTestModel hitTestModel,
}) =>
    new StoryTimeRandomizer(
      storyModel: storyModel,
      child: new DebugEnabler(
        debugModel: debugModel,
        child: new DefaultAssetBundle(
          bundle: defaultBundle,
          child: new ScopedModel<HitTestModel>(
            model: hitTestModel,
            child: armadillo,
          ),
        ),
      ),
    );

Widget _buildPerformanceOverlay({Widget child}) => new Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        child,
        new Positioned(
          top: 0.0,
          left: 0.0,
          right: 0.0,
          child: new IgnorePointer(child: new PerformanceOverlay.allEnabled()),
        ),
        new Align(
          alignment: FractionalOffset.topCenter,
          child: new Text(
            'User shell performance',
            style: new TextStyle(color: Colors.black),
          ),
        ),
      ],
    );

class _DeviceMapWatcherImpl extends DeviceMapWatcher {
  ValueChanged<Map<String, String>> onProfileChanged;

  _DeviceMapWatcherImpl({this.onProfileChanged});
  @override
  void onDeviceMapChange(DeviceMapEntry entry) {
    Object decodedJson = json.decode(entry.profile);
    if (decodedJson is Map<String, String>) {
      onProfileChanged(decodedJson);
    } else {
      log.severe(
        'Device profile expected to be a map of strings!'
            ' ${entry.profile}',
      );
    }
  }
}
