// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';

import 'conductor_model.dart';
import 'context_model.dart';
import 'edge_scroll_drag_target.dart';
import 'expand_suggestion.dart';
import 'interruption_overlay.dart';
import 'quick_settings.dart';
import 'peek_model.dart';
import 'peeking_overlay.dart';
import 'selected_suggestion_overlay.dart';
import 'size_model.dart';
import 'splash_suggestion.dart';
import 'story.dart';
import 'story_cluster.dart';
import 'story_model.dart';
import 'suggestion.dart';
import 'suggestion_list.dart';
import 'suggestion_model.dart';

const double _kSuggestionOverlayPullScrollOffset = 100.0;
const double _kSuggestionOverlayScrollFactor = 1.2;

/// Called when an overlay becomes active or inactive.
typedef void OnOverlayChanged(bool active);

/// Manages the position, size, and state of the story list, user context,
/// suggestion overlay, device extensions. interruption overlay, and quick
/// settings overlay.
class Conductor extends StatefulWidget {
  /// Called when the quick settings overlay becomes active or inactive.
  final OnOverlayChanged onQuickSettingsOverlayChanged;

  /// Called when the suggestions overlay becomes active or inactive.
  final OnOverlayChanged onSuggestionsOverlayChanged;

  /// Called when the user selects log out.
  final VoidCallback onLogoutSelected;

  /// Called when the user selects log out and clear the ledger.
  final VoidCallback onClearLedgerSelected;

  /// Called when the user taps the user context.
  final VoidCallback onUserContextTapped;

  /// The key of the interruption overlay.
  final GlobalKey<InterruptionOverlayState> interruptionOverlayKey;

  /// Called when an interruption is no longer showing.
  final OnInterruptionDismissed onInterruptionDismissed;

  /// Constructor.
  Conductor({
    Key key,
    this.onQuickSettingsOverlayChanged,
    this.onSuggestionsOverlayChanged,
    this.onLogoutSelected,
    this.onClearLedgerSelected,
    this.onUserContextTapped,
    this.interruptionOverlayKey,
    this.onInterruptionDismissed,
  })
      : super(key: key);

  @override
  ConductorState createState() => new ConductorState();
}

/// Manages the state for [Conductor].
class ConductorState extends State<Conductor> {
  final GlobalKey<SuggestionListState> _suggestionListKey =
      new GlobalKey<SuggestionListState>();
  final ScrollController _suggestionListScrollController =
      new ScrollController();
  final GlobalKey<QuickSettingsOverlayState> _quickSettingsOverlayKey =
      new GlobalKey<QuickSettingsOverlayState>();
  final GlobalKey<PeekingOverlayState> _suggestionOverlayKey =
      new GlobalKey<PeekingOverlayState>();
  final GlobalKey<EdgeScrollDragTargetState> _edgeScrollDragTargetKey =
      new GlobalKey<EdgeScrollDragTargetState>();

  final ScrollController _scrollController = new ScrollController();

  /// The key for adding [Suggestion]s to the [SelectedSuggestionOverlay].  This
  /// is to allow us to animate from a [Suggestion] in an open [SuggestionList]
  /// to a [Story] focused in the StoryList.
  final GlobalKey<SelectedSuggestionOverlayState>
      _selectedSuggestionOverlayKey =
      new GlobalKey<SelectedSuggestionOverlayState>();

  final FocusScopeNode _conductorFocusNode = new FocusScopeNode();
  final FocusNode _askFocusNode = new FocusNode();

  bool _ignoreNextScrollOffsetChange = false;

  Timer _storyFocusTimer;

  @override
  Widget build(BuildContext context) =>
      new ScopedModelDescendant<ConductorModel>(
        builder: (_, __, ConductorModel conductorModel) =>
            new ScopedModelDescendant<SizeModel>(
              builder: (
                BuildContext context,
                Widget child,
                SizeModel sizeModel,
              ) =>
                  new ScopedModelDescendant<IdleModel>(
                    builder: (
                      BuildContext context,
                      Widget child,
                      IdleModel idleModel,
                    ) =>
                        new Transform(
                          transform: new Matrix4.translationValues(
                            lerpDouble(
                              0.0,
                              sizeModel.screenSize.width,
                              idleModel.value,
                            ),
                            0.0,
                            0.0,
                          ),
                          child: new Stack(
                            overflow: Overflow.visible,
                            children: <Widget>[
                              new Positioned.fill(
                                child: new Offstage(
                                  offstage: idleModel.value == 1.0,
                                  child: child,
                                ),
                              ),
                              new Positioned(
                                top: 0.0,
                                left: -sizeModel.screenSize.width,
                                width: sizeModel.screenSize.width,
                                height: sizeModel.screenSize.height,
                                child: new Offstage(
                                  offstage: idleModel.value == 0.0,
                                  child: conductorModel.idleModeBuilder.build(
                                    context,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    child: new Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (_) {
                        // TODO: remove this hack when Mozart focus is fixed (MZ-118)
                        // HACK: Due to a mozart focus issue we need to focus when the mozart
                        // window this widget is in is first tapped.
                        if (!_askFocusNode.hasFocus) {
                          _conductorFocusNode.requestFocus(_askFocusNode);
                        }
                      },
                      child: _buildParts(context, conductorModel),
                    ),
                  ),
            ),
      );

  /// Note in particular the magic we're employing here to make the user
  /// state appear to be a part of the story list:
  /// By giving the story list bottom padding and clipping its bottom to the
  /// size of the final user state bar we have the user state appear to be
  /// a part of the story list and yet prevent the story list from painting
  /// behind it.
  Widget _buildParts(
    BuildContext context,
    ConductorModel conductorModel,
  ) =>
      new FocusScope(
        autofocus: true,
        node: _conductorFocusNode,
        child: new Stack(
          fit: StackFit.passthrough,
          children: <Widget>[
            /// Story List.
            conductorModel.recentsBuilder.build(
              context,
              scrollController: _scrollController,
              onScroll: (double scrollOffset) {
                if (_ignoreNextScrollOffsetChange) {
                  _ignoreNextScrollOffsetChange = false;
                  return;
                }

                // Ignore top padding of storylist when looking at scroll offset
                // to determine Now state.
                conductorModel.nowBuilder.onRecentsScrollOffsetChanged(
                  scrollOffset + SizeModel.of(context).storyListTopPadding,
                );

                // Peak suggestion overlay more when overscrolling.
                if (scrollOffset < -_kSuggestionOverlayPullScrollOffset &&
                    _suggestionOverlayKey.currentState.hiding) {
                  _suggestionOverlayKey.currentState.setValue(
                    SizeModel.of(context).suggestionPeekHeight -
                        (scrollOffset + _kSuggestionOverlayPullScrollOffset) *
                            _kSuggestionOverlayScrollFactor,
                  );
                }
              },
              onStoryClusterFocusStarted: () {
                // Lock scrolling.
                conductorModel.recentsBuilder.onStoryFocused();
                _edgeScrollDragTargetKey.currentState.disable();
                _minimizeNow();
              },
              onStoryClusterFocusCompleted: (StoryCluster storyCluster) {
                _focusStoryCluster(storyCluster);
              },
              onStoryClusterVerticalEdgeHover: () => goToOrigin(),
            ),

            // Now.
            conductorModel.nowBuilder.build(
              context,
              onQuickSettingsProgressChange: (double quickSettingsProgress) =>
                  conductorModel.recentsBuilder
                      .onQuickSettingsProgressChanged(quickSettingsProgress),
              onMinimizedTap: () => goToOrigin(),
              onMinimizedLongPress: () =>
                  _quickSettingsOverlayKey.currentState.show(),
              onQuickSettingsMaximized: () {
                // When quick settings starts being shown, scroll to 0.0.
                _scrollController.animateTo(
                  0.0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.fastOutSlowIn,
                );
              },
              onMinimize: () {
                PeekModel.of(context).nowMinimized = true;
                _suggestionOverlayKey.currentState.hide();
              },
              onMaximize: () {
                PeekModel.of(context).nowMinimized = false;
                _suggestionOverlayKey.currentState.hide();
              },
              onBarVerticalDragUpdate: (DragUpdateDetails details) =>
                  _suggestionOverlayKey.currentState
                      .onVerticalDragUpdate(details),
              onBarVerticalDragEnd: (DragEndDetails details) =>
                  _suggestionOverlayKey.currentState.onVerticalDragEnd(details),
              onOverscrollThresholdRelease: () =>
                  _suggestionOverlayKey.currentState.show(),
              scrollController: _scrollController,
              onLogoutSelected: widget.onLogoutSelected,
              onClearLedgerSelected: widget.onClearLedgerSelected,
              onUserContextTapped: widget.onUserContextTapped,
              onMinimizedContextTapped: () =>
                  _suggestionOverlayKey.currentState.show(),
            ),

            // Suggestions Overlay.
            _getSuggestionOverlay(),

            // Selected Suggestion Overlay.
            // This is only visible in transitoning the user from a Suggestion
            // in an open SuggestionList to a focused Story in the StoryList.
            new SelectedSuggestionOverlay(
              key: _selectedSuggestionOverlayKey,
            ),

            // Interruption Overlay.
            new InterruptionOverlay(
              key: widget.interruptionOverlayKey,
              onSuggestionSelected: _onSuggestionSelected,
              onInterruptionDismissed: widget.onInterruptionDismissed,
            ),

            // Quick Settings Overlay.
            new QuickSettingsOverlay(
              key: _quickSettingsOverlayKey,
              onProgressChanged: (double progress) {
                if (progress == 0.0) {
                  widget.onQuickSettingsOverlayChanged?.call(false);
                } else {
                  widget.onQuickSettingsOverlayChanged?.call(true);
                }
              },
              onLogoutSelected: widget.onLogoutSelected,
              onClearLedgerSelected: widget.onClearLedgerSelected,
            ),

            // Top and bottom edge scrolling drag targets.
            new Positioned.fill(
              child: new EdgeScrollDragTarget(
                key: _edgeScrollDragTargetKey,
                scrollController: _scrollController,
              ),
            ),
          ],
        ),
      );

  Widget _getSuggestionOverlay() => new ScopedModelDescendant<SizeModel>(
        builder: (
          BuildContext context,
          Widget child,
          SizeModel sizeModel,
        ) =>
            new PeekingOverlay(
              key: _suggestionOverlayKey,
              peekHeight: sizeModel.suggestionPeekHeight,
              dragHandleHeight: sizeModel.askHeight,
              onHide: () {
                widget.onSuggestionsOverlayChanged?.call(false);
                if (_suggestionListScrollController.hasClients) {
                  _suggestionListScrollController.animateTo(
                    0.0,
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.fastOutSlowIn,
                  );
                }
                _suggestionListKey.currentState?.stopAsking();
              },
              onShow: () {
                widget.onSuggestionsOverlayChanged?.call(true);
              },
              child: new SuggestionList(
                key: _suggestionListKey,
                scrollController: _suggestionListScrollController,
                onAskingStarted: () {
                  _suggestionOverlayKey.currentState.show();
                },
                onSuggestionSelected: _onSuggestionSelected,
                askFocusNode: _askFocusNode,
              ),
            ),
      );

  void _onSuggestionSelected(
    Suggestion suggestion,
    Rect globalBounds,
  ) {
    SuggestionModel.of(context).onSuggestionSelected(suggestion);

    if (suggestion.selectionType == SelectionType.closeSuggestions) {
      _suggestionOverlayKey.currentState.hide();
    } else {
      _selectedSuggestionOverlayKey.currentState.suggestionSelected(
        expansionBehavior: suggestion.selectionType == SelectionType.launchStory
            ? new ExpandSuggestion(
                suggestion: suggestion,
                suggestionInitialGlobalBounds: globalBounds,
              )
            : new SplashSuggestion(
                suggestion: suggestion,
                suggestionInitialGlobalBounds: globalBounds,
              ),
      );
      _minimizeNow();
    }
  }

  void _defocus(StoryModel storyModel) {
    // Unfocus all story clusters.
    storyModel.storyClusters.forEach(
      (StoryCluster storyCluster) => storyCluster.unFocus(),
    );

    // Unlock scrolling.
    ConductorModel.of(context).recentsBuilder.onStoryUnfocused();
    _edgeScrollDragTargetKey.currentState.enable();
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn,
    );
  }

  void _focusStoryCluster(
    StoryCluster storyCluster,
  ) {
    StoryModel storyModel = StoryModel.of(context);

    // Tell the [StoryModel] the story is now in focus.  This will move the
    // [Story] to the front of the [StoryList].
    storyModel.interactionStarted(storyCluster);

    // We need to set the scroll offset to 0.0 to ensure the story
    // bars don't become untouchable when fully focused:
    // If we're at a scroll offset other than zero, the RenderStoryListBody
    // might not be as big as it would need to be to fully cover the screen and
    // thus would have areas where its painting but not receiving hit testing.
    // Right now the RenderStoryListBody ensures that its at least the size of
    // the screen when we're focused but doesn't take into account the scroll
    // offset.  It seems weird to size the RenderStoryListBody based on the
    // scroll offset and it also seems weird to scroll to offset 0.0 from some
    // arbitrary scroll offset when we defocus so this solves both issues with
    // one stone.
    //
    // If we don't ignore the onScroll resulting from setting the scroll offset
    // to 0.0 we will inadvertently maximize now and peek the suggestion
    // overlay.
    _ignoreNextScrollOffsetChange = true;
    _scrollController.jumpTo(0.0);

    ConductorModel.of(context).recentsBuilder.onStoryFocused();
    _edgeScrollDragTargetKey.currentState.disable();
  }

  void _minimizeNow() {
    ConductorModel.of(context).nowBuilder.onMinimize();
    PeekModel.of(context).nowMinimized = true;
    _suggestionOverlayKey.currentState.hide();
  }

  /// Returns the state of the children to their initial values.
  /// This includes:
  /// 1) Unfocusing any focused stories.
  /// 2) Maximizing now.
  /// 3) Enabling scrolling of the story list.
  /// 4) Scrolling to the beginning of the story list.
  /// 5) Peeking the suggestion list.
  void goToOrigin() {
    StoryModel storyModel = StoryModel.of(context);
    _defocus(storyModel);
    ConductorModel.of(context).nowBuilder.onMaximize();
    storyModel.interactionStopped();
    storyModel.clearPlaceHolderStoryClusters();
  }

  /// Called to request the conductor focus on the cluster with [storyId].
  void requestStoryFocus(StoryId storyId, {bool jumpToFinish: true}) {
    ConductorModel.of(context).recentsBuilder.onStoryFocused();
    _edgeScrollDragTargetKey.currentState.disable();
    _minimizeNow();
    _focusOnStory(storyId, jumpToFinish: jumpToFinish);
  }

  void _focusOnStory(StoryId storyId, {bool jumpToFinish: true}) {
    StoryModel storyModel = StoryModel.of(context);
    List<StoryCluster> targetStoryClusters =
        storyModel.storyClusters.where((StoryCluster storyCluster) {
      bool result = false;
      storyCluster.stories.forEach((Story story) {
        if (story.id == storyId) {
          result = true;
        }
      });
      return result;
    }).toList();

    // There should be only one story cluster with a story with this id.  If
    // that's not true, bail out.
    if (targetStoryClusters.length != 1) {
      print(
          'WARNING: Found ${targetStoryClusters.length} story clusters with a story with id $storyId. Returning to origin.');
      goToOrigin();
    } else {
      // Unfocus all story clusters.
      storyModel.storyClusters.forEach(
        (StoryCluster storyCluster) => storyCluster.unFocus(),
      );

      // Ensure the focused story is completely expanded.
      targetStoryClusters[0].focusModel.jump(1.0);
      targetStoryClusters[0].storyClusterEntranceTransitionModel.jump(1.0);

      // Ensure the focused story's story bar is full open.
      targetStoryClusters[0].maximizeStoryBars(jumpToFinish: jumpToFinish);

      // Focus on the story cluster.
      _focusStoryCluster(targetStoryClusters[0]);
    }

    // Unhide selected suggestion in suggestion list.
    _suggestionListKey.currentState.resetSelection();
  }

  @override
  void dispose() {
    _askFocusNode.dispose();
    _conductorFocusNode.detach();
    if (_storyFocusTimer != null && _storyFocusTimer.isActive) {
      _storyFocusTimer.cancel();
    }
    super.dispose();
  }
}
