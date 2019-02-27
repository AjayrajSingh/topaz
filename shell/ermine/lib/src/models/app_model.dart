// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:flutter/material.dart';

import 'package:fidl_fuchsia_modular/fidl_async.dart'
    show
        SessionShellContextProxy,
        ComponentContextProxy,
        FocusControllerProxy,
        FocusRequestWatcherBinding,
        PuppetMaster,
        PuppetMasterProxy,
        StoryProviderProxy,
        StoryProviderWatcherBinding,
        SuggestionProvider,
        SuggestionProviderBinding,
        SuggestionProviderProxy;
import 'package:fidl_fuchsia_shell_ermine/fidl_async.dart' show AskBarProxy;
import 'package:fidl_fuchsia_sys/fidl_async.dart'
    show
        ComponentControllerProxy,
        LaunchInfo,
        ServiceList,
        ServiceProviderBinding;
import 'package:fidl_fuchsia_ui_app/fidl_async.dart' show ViewProviderProxy;
import 'package:fidl_fuchsia_ui_gfx/fidl_async.dart'
    show ExportToken, ImportToken;
import 'package:fidl_fuchsia_ui_policy/fidl_async.dart' show PresentationProxy;
import 'package:fuchsia_services/services.dart'
    show connectToEnvironmentService, ServicesConnector, StartupContext;
import 'package:fuchsia_scenic_flutter/child_view_connection.dart'
    show ChildViewConnection;
import 'package:lib.widgets/model.dart' show Model;
import 'package:lib.widgets/utils.dart' show PointerEventsListener;
import 'package:zircon/zircon.dart';

import '../utils/elevations.dart';
import '../utils/key_chord_listener.dart' show KeyChordListener;
import '../utils/session_shell_services.dart' show SessionShellServices;
import 'ermine_service_provider.dart' show ErmineServiceProvider;
import 'package_proposer.dart' show PackageProposer;
import 'story_manager.dart'
    show FocusRequestWatcherImpl, StoryManager, StoryProviderWatcherImpl;
import 'web_proposer.dart' show WebProposer;

const _kErmineAskModuleUrl =
    'fuchsia-pkg://fuchsia.com/ermine_ask_module#meta/ermine_ask_module.cmx';

/// Model that manages all the application state of this session shell.
class AppModel extends Model {
  final _sessionShellContext = SessionShellContextProxy();
  final _componentContext = ComponentContextProxy();
  final _pointerEventsListener = PointerEventsListener();
  final _presentation = PresentationProxy();
  final _storyProvider = StoryProviderProxy();
  final _puppetMaster = PuppetMasterProxy();
  final _storyProviderWatcherBinding = StoryProviderWatcherBinding();
  final _focusController = FocusControllerProxy();
  final _focusRequestWatcherBinding = FocusRequestWatcherBinding();
  final _componentControllerProxy = ComponentControllerProxy();
  final _suggestionProvider = SuggestionProviderProxy();
  final _ask = AskBarProxy();
  final _packageProposer = PackageProposer();
  final _webProposer = WebProposer();

  // ignore: unused_field
  SessionShellServices _sessionShellServices;

  final String backgroundImageUrl = 'assets/images/fuchsia.png';
  final Color backgroundColor = Colors.grey[850];
  final StartupContext startupContext = StartupContext.fromStartupInfo();

  ValueNotifier<bool> askVisibility = ValueNotifier(false);
  ValueNotifier<ChildViewConnection> askChildViewConnection =
      ValueNotifier<ChildViewConnection>(null);

  StoryManager storyManager;

  AppModel() {
    connectToEnvironmentService(_sessionShellContext);
    connectToEnvironmentService(_componentContext);
    connectToEnvironmentService(_puppetMaster);
    _packageProposer.start();
    _webProposer.start();

    _sessionShellServices = SessionShellServices(
      sessionShellContext: _sessionShellContext,
    )..advertise();

    _sessionShellContext
      ..getFocusController(_focusController.ctrl.request())
      ..getPresentation(_presentation.ctrl.request())
      ..getStoryProvider(_storyProvider.ctrl.request())
      ..getSuggestionProvider(_suggestionProvider.ctrl.request());

    storyManager = StoryManager(
      context: _sessionShellContext,
      puppetMaster: _puppetMaster,
    )..advertise(startupContext);

    _storyProvider.watch(
      _storyProviderWatcherBinding.wrap(StoryProviderWatcherImpl(storyManager)),
    );

    _focusController.watchRequest(
      _focusRequestWatcherBinding.wrap(FocusRequestWatcherImpl(storyManager)),
    );

    KeyChordListener(
      onMeta: onMeta,
      onLogout: _sessionShellContext.logout,
      onCancel: onCancel,
    ).listen(_presentation);

    // Load the ask bar.
    _loadAskBar();
  }

  /// Called after runApp which initializes flutter's gesture system.
  void onStarted() {
    _pointerEventsListener.listen(_presentation);
    // Display the Ask bar after a brief duration.
    Timer(Duration(milliseconds: 500), onMeta);
  }

  void _loadAskBar() {
    final serviceConnector = ServicesConnector();

    startupContext.launcher.createComponent(
      LaunchInfo(
        url: _kErmineAskModuleUrl,
        directoryRequest: serviceConnector.request(),
        additionalServices: ServiceList(
          names: <String>[
            PuppetMaster.$serviceName,
            SuggestionProvider.$serviceName
          ],
          provider: ServiceProviderBinding().wrap(
            ErmineServiceProvider()
              ..advertise<SuggestionProvider>(
                name: SuggestionProvider.$serviceName,
                service: _suggestionProvider,
                binding: SuggestionProviderBinding(),
              ),
          ),
        ),
      ),
      _componentControllerProxy.ctrl.request(),
    );

    final viewProvider = ViewProviderProxy();
    serviceConnector
      ..connectToService(viewProvider.ctrl)
      ..connectToService(_ask.ctrl)
      ..close();

    // Create a token pair for the newly-created View.
    final tokenPair = EventPairPair();
    assert(tokenPair.status == ZX.OK);
    final viewHolderToken = ImportToken(value: tokenPair.first);
    final viewToken = ExportToken(value: tokenPair.second);

    viewProvider.createView(viewToken.value, null, null);
    viewProvider.ctrl.close();

    // Load the Ask mod at elevation.
    _ask
      ..onHidden.forEach((_) => askVisibility.value = false)
      ..onVisible.forEach((_) => askVisibility.value = true)
      ..load(elevations.systemOverlayElevation);

    askChildViewConnection.value =
        ChildViewConnection.fromImportToken(viewHolderToken);
  }

  /// Shows the Ask bar and sets the focus on it.
  void onMeta() => _ask.show();

  /// Called when tapped behind Ask bar, quick settings, notifications or the
  /// Escape key was pressed.
  void onCancel() => _ask.hide();
}
