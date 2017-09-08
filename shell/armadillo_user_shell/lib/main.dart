// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:application.lib.app.dart/app.dart';
import 'package:lib.media.dart/audio_policy.dart';
import 'package:armadillo/armadillo.dart';
import 'package:armadillo/conductor.dart';
import 'package:armadillo/context_model.dart';
import 'package:armadillo/debug_enabler.dart';
import 'package:armadillo/debug_model.dart';
import 'package:armadillo/idle_mode_builder.dart';
import 'package:armadillo/interruption_overlay.dart';
import 'package:armadillo/now_builder.dart';
import 'package:armadillo/panel_resizing_model.dart';
import 'package:armadillo/peek_model.dart';
import 'package:armadillo/power_model.dart';
import 'package:armadillo/quick_settings_progress_model.dart';
import 'package:armadillo/recents_builder.dart';
import 'package:armadillo/size_model.dart';
import 'package:armadillo/story_cluster.dart';
import 'package:armadillo/story_cluster_drag_state_model.dart';
import 'package:armadillo/story_drag_transition_model.dart';
import 'package:armadillo/story_model.dart';
import 'package:armadillo/story_rearrangement_scrim_model.dart';
import 'package:armadillo/story_time_randomizer.dart';
import 'package:armadillo/story.dart';
import 'package:armadillo/suggestion_model.dart';
import 'package:armadillo/volume_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.power.fidl/power_manager.fidl.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/modular.dart';
import 'package:lib.widgets/widgets.dart';
import 'package:sysui_widgets/default_bundle.dart';

import 'armadillo_user_shell_model.dart';
import 'audio_policy_volume_model.dart';
import 'context_provider_context_model.dart';
import 'focus_request_watcher_impl.dart';
import 'hit_test_model.dart';
import 'initial_focus_setter.dart';
import 'power_manager_power_model.dart';
import 'story_provider_story_generator.dart';
import 'suggestion_provider_suggestion_model.dart';
import 'user_logoutter.dart';

/// Set to true to enable the performance overlay.
const bool _kShowPerformanceOverlay = false;

/// Set to true to enable dumping of all errors, not just the first one.
const bool _kDumpAllErrors = false;

Future<Null> main() async {
  SizeModel sizeModel = new SizeModel();
  runApp(buildArmadilloUserShell(
    logName: 'armadillo',
    sizeModel: sizeModel,
    idleModeBuilder: new IdleModeBuilder(),
    nowBuilder: new NowBuilder(),
    recentsBuilder: new RecentsBuilder(),
  ));
}

/// Builds the armadillo user shell.
Widget buildArmadilloUserShell({
  String logName,
  SizeModel sizeModel,
  IdleModeBuilder idleModeBuilder,
  NowBuilder nowBuilder,
  RecentsBuilder recentsBuilder,
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
  );
  StoryClusterDragStateModel storyClusterDragStateModel =
      new StoryClusterDragStateModel();
  StoryRearrangementScrimModel storyRearrangementScrimModel =
      new StoryRearrangementScrimModel();
  storyClusterDragStateModel.addListener(
    () => storyRearrangementScrimModel
        .onDragAcceptableStateChanged(storyClusterDragStateModel.isAcceptable),
  );
  storyClusterDragStateModel.addListener(
    () => storyProviderStoryGenerator
        .onDraggingChanged(storyClusterDragStateModel.isDragging),
  );
  StoryDragTransitionModel storyDragTransitionModel =
      new StoryDragTransitionModel();
  storyClusterDragStateModel.addListener(
    () => storyDragTransitionModel
        .onDragStateChanged(storyClusterDragStateModel.isDragging),
  );

  UserLogoutter userLogoutter = new UserLogoutter();
  GlobalKey<ConductorState> conductorKey = new GlobalKey<ConductorState>();
  GlobalKey<InterruptionOverlayState> interruptionOverlayKey =
      new GlobalKey<InterruptionOverlayState>();
  SuggestionProviderSuggestionModel suggestionProviderSuggestionModel =
      new SuggestionProviderSuggestionModel(
    hitTestModel: hitTestModel,
    interruptionOverlayKey: interruptionOverlayKey,
  );

  StoryModel storyModel = new StoryModel(
    onFocusChanged: suggestionProviderSuggestionModel.storyClusterFocusChanged,
    onDeleteStoryCluster: storyProviderStoryGenerator.onDeleteStoryCluster,
  );
  storyProviderStoryGenerator.addListener(
    () => storyModel.onStoryClustersChanged(
          storyProviderStoryGenerator.storyClusters,
        ),
  );

  suggestionProviderSuggestionModel.storyModel = storyModel;
  suggestionProviderSuggestionModel.addOnFocusLossListener(() {
    conductorKey.currentState.goToOrigin();
  });

  StoryFocuser storyFocuser = (String storyId) {
    scheduleMicrotask(() {
      conductorKey.currentState.requestStoryFocus(
        new StoryId(storyId),
        jumpToFinish: false,
      );
    });
  };

  initialFocusSetter.storyFocuser = storyFocuser;

  FocusRequestWatcherImpl focusRequestWatcher = new FocusRequestWatcherImpl(
    onFocusRequest: (String storyId) {
      // If we don't know about the story that we've been asked to focus, update
      // the story list first.
      if (!storyProviderStoryGenerator.containsStory(storyId)) {
        log.info(
          'Story $storyId isn\'t in the list, querying story provider...',
        );
        storyProviderStoryGenerator.update(() => storyFocuser(storyId));
      } else {
        storyFocuser(storyId);
      }
    },
  );

  ContextProviderContextModel contextProviderContextModel =
      new ContextProviderContextModel();

  ApplicationContext applicationContext =
      new ApplicationContext.fromStartupInfo();

  AudioPolicy audioPolicy = new AudioPolicy(
    applicationContext.environmentServices,
  );
  VolumeModel volumeModel = new AudioPolicyVolumeModel(
    audioPolicy: audioPolicy,
  );

  PowerManagerProxy powerManagerProxy = new PowerManagerProxy();
  connectToService(
    applicationContext.environmentServices,
    powerManagerProxy.ctrl,
  );

  PowerManagerPowerModel powerModel = new PowerManagerPowerModel(
    powerManager: powerManagerProxy,
  );

  ArmadilloUserShellModel armadilloUserShellModel = new ArmadilloUserShellModel(
    storyProviderStoryGenerator: storyProviderStoryGenerator,
    suggestionProviderSuggestionModel: suggestionProviderSuggestionModel,
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
    },
    onWallpaperChosen: contextProviderContextModel.onWallpaperChosen,
  );

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
          quickSettingsProgressModel.quickSettingsProgress,
        ),
  );

  Conductor conductor = new Conductor(
    key: conductorKey,
    onQuickSettingsOverlayChanged: hitTestModel.onQuickSettingsOverlayChanged,
    onSuggestionsOverlayChanged: hitTestModel.onSuggestionsOverlayChanged,
    onLogoutSelected: userLogoutter.logout,
    onClearLedgerSelected: userLogoutter.logoutAndResetLedgerState,
    interruptionOverlayKey: interruptionOverlayKey,
    onInterruptionDismissed:
        suggestionProviderSuggestionModel.onInterruptionDismissal,
    onUserContextTapped: armadilloUserShellModel.onUserContextTapped,
    idleModeBuilder: idleModeBuilder,
    nowBuilder: nowBuilder,
    recentsBuilder: recentsBuilder,
  );

  DebugModel debugModel = new DebugModel();
  PanelResizingModel panelResizingModel = new PanelResizingModel();

  sizeModel.addListener(
    () => storyModel.updateLayouts(
          new Size(
            sizeModel.storySize.width,
            sizeModel.storySize.height - SizeModel.kStoryBarMaximizedHeight,
          ),
        ),
  );
  sizeModel.screenSize = ui.window.physicalSize / ui.window.devicePixelRatio;

  Widget app = new ScopedModel<StoryDragTransitionModel>(
    model: storyDragTransitionModel,
    child: _buildApp(
      storyModel: storyModel,
      storyProviderStoryGenerator: storyProviderStoryGenerator,
      debugModel: debugModel,
      armadillo: new Armadillo(
        scopedModelBuilders: <WrapperBuilder>[
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
    child: new CheckedModeBanner(child: userShellWidget),
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
