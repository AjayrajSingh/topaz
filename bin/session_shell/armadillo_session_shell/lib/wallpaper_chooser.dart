// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:fidl_fuchsia_mem/fidl.dart' as fuchsia_mem;
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.proposal.dart/proposal.dart';
import 'package:lib.story.dart/story.dart';
import 'package:zircon/zircon.dart';

const String _kWallpapersLinkKey = 'wallpapers';
// const String _kImageSelectorModulePath = 'gallery';
// const List<String> _kImageSelectorLinkPath = const <String>['root'];
// const String _kImageSelectorLinkName = 'selection';
// const String _kImageSelectorRootKey = 'image selection';
// const String _kImageSelectorImageListKey = 'selected images';
// const List<StoryInfoExtraEntry> _kImageSelectorStoryExtraInfo =
//     const <StoryInfoExtraEntry>[
//   const StoryInfoExtraEntry(key: 'color', value: '0xFFA5A700'),
// ];
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

  _ProposalListener _proposalListener;

  /// Constructor.
  WallpaperChooser({this.onWallpaperChosen});

  /// Begins proposing the wallpaper chooser module be run.
  void start(
    FocusProvider focusProvider,
    StoryProvider storyProvider,
    IntelligenceServices intelligenceServices,
    Link link,
  ) {
    _proposalListener = new _ProposalListener(
      storyProvider: storyProvider,
      linkProxy: _changeWallpaperLink,
      focusProvider: focusProvider,
      onWallpaperChosen: (List<String> images) {
        log.info('wallpaper chosen: $images');
        var jsonString = json.encode(images);
        var jsonList = Uint8List.fromList(utf8.encode(jsonString));
        var data = fuchsia_mem.Buffer(
          vmo: new SizedVmo.fromUint8List(jsonList),
          size: jsonList.length,
        );
        link.set(<String>[_kWallpapersLinkKey], data);
        onWallpaperChosen(images);
      },
    );

    _proposer.start(
      intelligenceServices: intelligenceServices,
      proposalListener: _proposalListener,
    );
  }

  /// Called when the Link json changes.
  void onLinkChanged(String encoded) {
    dynamic decodedJson = json.decode(encoded);
    if (decodedJson == null ||
        !(decodedJson is Map) ||
        !decodedJson.containsKey(_kWallpapersLinkKey)) {
      return;
    }
    onWallpaperChosen(decodedJson[_kWallpapersLinkKey]);
  }

  /// Closes any open handles.
  void stop() {
    _proposalListener.stop();
    _proposer.stop();
    _changeWallpaperLink.ctrl.close();
  }
}

class _Proposer {
  final QueryHandlerBinding _queryHandlerBinding = new QueryHandlerBinding();
  _QueryHandlerImpl _queryHandlerImpl;

  void start({
    IntelligenceServices intelligenceServices,
    ProposalListener proposalListener,
  }) {
    _queryHandlerImpl =
        new _QueryHandlerImpl(proposalListener: proposalListener);
    intelligenceServices.registerQueryHandler(
      _queryHandlerBinding.wrap(_queryHandlerImpl),
    );
  }

  void stop() {
    _queryHandlerImpl.stop();
    _queryHandlerBinding.close();
  }
}

class _QueryHandlerImpl extends QueryHandler {
  final Set<ProposalListenerBinding> _bindings =
      new Set<ProposalListenerBinding>();

  final ProposalListener proposalListener;

  _QueryHandlerImpl({this.proposalListener});

  @override
  Future<Null> onQuery(
    UserInput query,
    void callback(QueryResponse response),
  ) async {
    List<Proposal> proposals = <Proposal>[];

    if ((query.text?.toLowerCase()?.startsWith('wal') ?? false) ||
        (query.text?.toLowerCase()?.contains('wallpaper') ?? false) ||
        (query.text?.toLowerCase()?.contains('change') ?? false)) {
      ProposalListenerBinding binding = new ProposalListenerBinding();
      _bindings.add(binding);
      proposals.add(await (ProposalBuilder(
        id: _kChooseWallpaperSuggestionHeadline,
        headline: _kChooseWallpaperSuggestionHeadline,
      )
            ..color = _kChooseWallpaperSuggestionColor
            ..imageUrl = _kChooseWallpaperSuggestionImageUrl
            ..listener = binding.wrap(proposalListener))
          .build());
    }

    callback(new QueryResponse(proposals: proposals));
  }

  void stop() {
    for (ProposalListenerBinding binding in _bindings) {
      binding.close();
    }
  }
}

class _ProposalListener extends ProposalListener {
  final StoryProvider storyProvider;
  final FocusProvider focusProvider;
  final LinkProxy linkProxy;
  final ValueChanged<List<String>> onWallpaperChosen;
  StoryControllerProxy storyControllerProxy;
  LinkWatcherBinding _linkWatcherBinding;
//  dynamic _lastDecodedJson;

  _ProposalListener({
    this.storyProvider,
    this.focusProvider,
    this.linkProxy,
    this.onWallpaperChosen,
  });

  @override
  void onProposalAccepted(String proposalId, String preloadedStoryId) {
    stop();

    // Per MF-13, this method is deprecated. PuppetMaster, which is available
    // to Session Shells (like Armadillo) expose the same functionality with
    // a slightly different API.
    /*
    storyProvider.createStoryWithInfo(
      _kImageSelectorModulePath,
      _kImageSelectorStoryExtraInfo,
      json.encode(
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
          var linkPath = new LinkPath(
              modulePath: _kImageSelectorLinkPath,
              linkName: _kImageSelectorLinkName);
          storyControllerProxy.getLink(linkPath, linkProxy.ctrl.request());
          storyControllerProxy?.ctrl?.close();
          storyControllerProxy = null;

          _linkWatcherBinding = new LinkWatcherBinding();
          linkProxy.watch(
            _linkWatcherBinding.wrap(
              new LinkWatcherImpl(
                onNotify: (String encoded) {
                  dynamic decodedJson = json.decode(encoded);
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
    */
  }

  void stop() {
    storyControllerProxy?.ctrl?.close();
    storyControllerProxy = null;
    _linkWatcherBinding?.close();
    _linkWatcherBinding = null;
  }
}
