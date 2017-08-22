// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:application.lib.app.dart/app.dart';
import 'package:apps.media.lib.dart/audio_policy.dart';
import 'package:apps.power-service.services/power_manager.fidl.dart';
import 'package:armadillo/armadillo.dart';
import 'package:armadillo/armadillo_drag_target.dart';
import 'package:armadillo/conductor.dart';
import 'package:armadillo/context_model.dart';
import 'package:armadillo/debug_enabler.dart';
import 'package:armadillo/debug_model.dart';
import 'package:armadillo/interruption_overlay.dart';
import 'package:armadillo/panel_resizing_model.dart';
import 'package:armadillo/peek_model.dart';
import 'package:armadillo/power_model.dart';
import 'package:armadillo/quick_settings_progress_model.dart';
import 'package:armadillo/size_model.dart';
import 'package:armadillo/story_cluster.dart';
import 'package:armadillo/story_cluster_drag_data.dart';
import 'package:armadillo/story_cluster_drag_state_model.dart';
import 'package:armadillo/story.dart';
import 'package:armadillo/story_drag_transition_model.dart';
import 'package:armadillo/story_model.dart';
import 'package:armadillo/story_rearrangement_scrim_model.dart';
import 'package:armadillo/story_time_randomizer.dart';
import 'package:armadillo/suggestion_model.dart';
import 'package:armadillo/user_shell_mode_model.dart';
import 'package:armadillo/volume_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lib.logging/logging.dart';
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
  setupLogger(name: 'armadillo');

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
    onLogoutTapped: userLogoutter.logout,
    onLogoutLongPressed: userLogoutter.logoutAndResetLedgerState,
    interruptionOverlayKey: interruptionOverlayKey,
    onInterruptionDismissed:
        suggestionProviderSuggestionModel.onInterruptionDismissal,
    onUserContextTapped: armadilloUserShellModel.onUserContextTapped,
  );

  DebugModel debugModel = new DebugModel();
  PanelResizingModel panelResizingModel = new PanelResizingModel();

  UserShellModeModel userShellModeModel = new UserShellModeModel();

  SizeModel sizeModel = new SizeModel(userShellModeModel: userShellModeModel);
  sizeModel.addListener(
    () => storyModel.updateLayouts(
          new Size(
            sizeModel.storySize.width,
            sizeModel.storySize.height - SizeModel.kStoryBarMaximizedHeight,
          ),
        ),
  );
  sizeModel.screenSize = ui.window.physicalSize / ui.window.devicePixelRatio;

  userShellModeModel.addListener(sizeModel.notifyListeners);

  Widget app = new ScopedModel<StoryDragTransitionModel>(
    model: storyDragTransitionModel,
    child: _buildApp(
      storyModel: storyModel,
      storyProviderStoryGenerator: storyProviderStoryGenerator,
      debugModel: debugModel,
      armadillo: new Armadillo(
        scopedModelBuilders: <WrapperBuilder>[
          (_, Widget child) => new ScopedModel<UserShellModeModel>(
                model: userShellModeModel,
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

  runApp(
    new WindowMediaQuery(
      onWindowMetricsChanged: () {
        sizeModel.screenSize =
            ui.window.physicalSize / ui.window.devicePixelRatio;
      },
      child: new CheckedModeBanner(child: userShellWidget),
    ),
  );

  await contextProviderContextModel.load();
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
          child: new Stack(
            fit: StackFit.passthrough,
            children: <Widget>[
              new ScopedModel<HitTestModel>(
                model: hitTestModel,
                child: armadillo,
              ),
              new Positioned(
                left: 0.0,
                top: 0.0,
                bottom: 0.0,
                width: 108.0,
                child: _buildDiscardDragTarget(
                  storyModel: storyModel,
                  storyProviderStoryGenerator: storyProviderStoryGenerator,
                  controller: new AnimationController(
                    vsync: new _TickerProvider(),
                    duration: const Duration(milliseconds: 200),
                  ),
                ),
              ),
              new Positioned(
                right: 0.0,
                top: 0.0,
                bottom: 0.0,
                width: 108.0,
                child: _buildDiscardDragTarget(
                  storyModel: storyModel,
                  storyProviderStoryGenerator: storyProviderStoryGenerator,
                  controller: new AnimationController(
                    vsync: new _TickerProvider(),
                    duration: const Duration(milliseconds: 200),
                  ),
                ),
              ),
            ],
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

Widget _buildDiscardDragTarget({
  StoryModel storyModel,
  StoryProviderStoryGenerator storyProviderStoryGenerator,
  AnimationController controller,
}) {
  CurvedAnimation curve = new CurvedAnimation(
    parent: controller,
    curve: Curves.fastOutSlowIn,
    reverseCurve: Curves.fastOutSlowIn,
  );
  bool wasEmpty = true;
  return new ArmadilloDragTarget<StoryClusterDragData>(
    onWillAccept: (_, __) => storyModel.storyClusters.every(
        (StoryCluster storyCluster) =>
            storyCluster.focusSimulationKey.currentState.progress == 0.0),
    onAccept: (StoryClusterDragData data, _, __) =>
        storyProviderStoryGenerator.removeStoryCluster(
          data.id,
        ),
    builder: (_, Map<StoryClusterDragData, Offset> candidateData, __) {
      if (candidateData.isEmpty && !wasEmpty) {
        controller.reverse();
      } else if (candidateData.isNotEmpty && wasEmpty) {
        controller.forward();
      }
      wasEmpty = candidateData.isEmpty;

      return new IgnorePointer(
        child: new ScopedModelDescendant<StoryDragTransitionModel>(
          builder: (
            BuildContext context,
            Widget child,
            StoryDragTransitionModel model,
          ) =>
              new Opacity(
                opacity: model.progress,
                child: child,
              ),
          child: new Container(
            color: Colors.black38,
            child: new Center(
              child: new ScaleTransition(
                scale: new Tween<double>(begin: 1.0, end: 1.4).animate(curve),
                child: new Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    new Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: 24.0,
                    ),
                    new Container(height: 8.0),
                    new Text(
                      'REMOVE',
                      style: new TextStyle(
                        fontSize: 10.0,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _TickerProvider extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => new Ticker(onTick);
}
