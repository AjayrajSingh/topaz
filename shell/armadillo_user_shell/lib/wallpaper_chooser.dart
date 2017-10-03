// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:lib.suggestion.fidl/ask_handler.fidl.dart';
import 'package:lib.suggestion.fidl/proposal.fidl.dart';
import 'package:lib.suggestion.fidl/proposal_publisher.fidl.dart';
import 'package:lib.suggestion.fidl/suggestion_display.fidl.dart';
import 'package:lib.suggestion.fidl/user_input.fidl.dart';
import 'package:lib.story.fidl/link.fidl.dart';
import 'package:lib.story.fidl/story_controller.fidl.dart';
import 'package:lib.story.fidl/story_info.fidl.dart';
import 'package:lib.story.fidl/story_provider.fidl.dart';
import 'package:lib.story.fidl/story_state.fidl.dart';
import 'package:lib.user.fidl/focus.fidl.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

const String _kWallpapersLinkKey = 'wallpapers';
const String _kImageSelectorModulePath = 'gallery';
const List<String> _kImageSelectorLinkPath = const <String>['root'];
const String _kImageSelectorLinkName = 'selection';
const String _kImageSelectorRootKey = 'image selection';
const String _kImageSelectorImageListKey = 'selected images';
const Map<String, String> _kImageSelectorStoryExtraInfo =
    const <String, String>{'color': '0xFFA5A700'};
const int _kChooseWallpaperSuggestionColor = 0xFFA5A700;
const String _kChooseWallpaperSuggestionHeadline = 'Change Wallpaper';
const String _kChooseWallpaperSuggestionImageUrl =
    '/system/data/sysui/aparna-home.png';

/// Chooses wallpaper for the user.
class WallpaperChooser {
  final _Proposer _proposer = new _Proposer();

  final LinkProxy _changeWallpaperLink = new LinkProxy();

  /// Called when different wallpaper is chosen.
  final ValueChanged<List<String>> onWallpaperChosen;

  _CustomAction _customAction;

  /// Constructor.
  WallpaperChooser({this.onWallpaperChosen});

  /// Begins proposing the wallpaper chooser module be run.
  void start(
    FocusProvider focusProvider,
    StoryProvider storyProvider,
    ProposalPublisher proposalPublisher,
    Link link,
  ) {
    _customAction = new _CustomAction(
      storyProvider: storyProvider,
      linkProxy: _changeWallpaperLink,
      focusProvider: focusProvider,
      onWallpaperChosen: (List<String> images) {
        log.info('wallpaper chosen: $images');
        link.set(<String>[_kWallpapersLinkKey], JSON.encode(images));
        onWallpaperChosen(images);
      },
    );

    _proposer.start(
      proposalPublisher: proposalPublisher,
      customAction: _customAction,
    );
  }

  /// Called when the Link json changes.
  void onLinkChanged(String json) {
    dynamic decodedJson = JSON.decode(json);
    if (decodedJson == null ||
        !(decodedJson is Map) ||
        !decodedJson.containsKey(_kWallpapersLinkKey)) {
      return;
    }
    onWallpaperChosen(decodedJson[_kWallpapersLinkKey]);
  }

  /// Closes any open handles.
  void stop() {
    _customAction.stop();
    _proposer.stop();
    _changeWallpaperLink.ctrl.close();
  }
}

class _Proposer {
  final AskHandlerBinding _askHandlerBinding = new AskHandlerBinding();
  _AskHandlerImpl _askHandlerImpl;

  void start({
    ProposalPublisher proposalPublisher,
    CustomAction customAction,
  }) {
    _askHandlerImpl = new _AskHandlerImpl(customAction: customAction);
    proposalPublisher.registerAskHandler(
      _askHandlerBinding.wrap(_askHandlerImpl),
    );
  }

  void stop() {
    _askHandlerImpl.stop();
    _askHandlerBinding.close();
  }
}

class _AskHandlerImpl extends AskHandler {
  final Set<CustomActionBinding> _bindings = new Set<CustomActionBinding>();

  final CustomAction customAction;

  _AskHandlerImpl({this.customAction});

  @override
  void ask(UserInput query, void callback(AskResponse response)) {
    List<Proposal> proposals = <Proposal>[];

    if ((query.text?.toLowerCase()?.startsWith('wal') ?? false) ||
        (query.text?.toLowerCase()?.contains('wallpaper') ?? false) ||
        (query.text?.toLowerCase()?.contains('change') ?? false)) {
      CustomActionBinding binding = new CustomActionBinding();
      _bindings.add(binding);
      proposals.add(
        new Proposal()
          ..id = _kChooseWallpaperSuggestionHeadline
          ..display = (new SuggestionDisplay()
            ..headline = _kChooseWallpaperSuggestionHeadline
            ..subheadline = ''
            ..details = ''
            ..color = _kChooseWallpaperSuggestionColor
            ..iconUrls = <String>[]
            ..imageType = SuggestionImageType.other
            ..imageUrl = _kChooseWallpaperSuggestionImageUrl
            ..annoyance = AnnoyanceType.none)
          ..onSelected = <Action>[
            new Action()..customAction = binding.wrap(customAction)
          ],
      );
    }

    callback(new AskResponse()..proposals = proposals);
  }

  void stop() {
    for (CustomActionBinding binding in _bindings) {
      binding.close();
    }
  }
}

class _CustomAction extends CustomAction {
  final StoryProvider storyProvider;
  final FocusProvider focusProvider;
  final LinkProxy linkProxy;
  final ValueChanged<List<String>> onWallpaperChosen;
  StoryControllerProxy storyControllerProxy;
  LinkWatcherBinding _linkWatcherBinding;
  dynamic _lastDecodedJson;

  _CustomAction({
    this.storyProvider,
    this.focusProvider,
    this.linkProxy,
    this.onWallpaperChosen,
  });

  @override
  void execute(void callback(List<Action> actions)) {
    stop();

    storyProvider.createStoryWithInfo(
      _kImageSelectorModulePath,
      _kImageSelectorStoryExtraInfo,
      JSON.encode(
        <String, List<String>>{},
      ),
      (String storyId) {
        storyControllerProxy = new StoryControllerProxy();
        storyProvider.getController(
          storyId,
          storyControllerProxy.ctrl.request(),
        );
        storyControllerProxy.getInfo((StoryInfo info, StoryState state) {
          focusProvider.request(info.id);
          storyControllerProxy.getLink(
            _kImageSelectorLinkPath,
            _kImageSelectorLinkName,
            linkProxy.ctrl.request(),
          );
          callback(null);
          storyControllerProxy?.ctrl?.close();
          storyControllerProxy = null;

          _linkWatcherBinding = new LinkWatcherBinding();
          linkProxy.watch(
            _linkWatcherBinding.wrap(
              new LinkWatcherImpl(
                onNotify: (String json) {
                  dynamic decodedJson = JSON.decode(json);
                  if (_lastDecodedJson != null && decodedJson == null) {
                    if (_lastDecodedJson is Map &&
                        _lastDecodedJson.containsKey(_kImageSelectorRootKey) &&
                        _lastDecodedJson[_kImageSelectorRootKey]
                            .containsKey(_kImageSelectorImageListKey)) {
                      onWallpaperChosen(
                        _lastDecodedJson[_kImageSelectorRootKey]
                            [_kImageSelectorImageListKey],
                      );
                      storyProvider.deleteStory(info.id, () {});
                    }
                  }
                  _lastDecodedJson = decodedJson;
                },
              ),
            ),
          );
        });
      },
    );
  }

  void stop() {
    storyControllerProxy?.ctrl?.close();
    storyControllerProxy = null;
    _linkWatcherBinding?.close();
    _linkWatcherBinding = null;
  }
}
