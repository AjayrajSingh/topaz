// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'suggestion.dart';
import 'suggestion_model.dart';
import 'suggestion_widget.dart';

const String _kImage = 'packages/armadillo/res/logo_googleg_24dpx4.png';
const Duration _kFadeInDuration = const Duration(milliseconds: 500);

/// The height of the ask section of the suggerion list.
const double kAskHeight = 84.0;

/// Called when a suggestion is selected.  [globalBounds] indicates the location
/// of the widget representing [suggestion] was on screen when it was selected.
typedef void OnSuggestionSelected(Suggestion suggestion, Rect globalBounds);

/// Displays a list of suggestions and provides a mechanism for asking for
/// new things to do.
class SuggestionList extends StatefulWidget {
  /// The controller to use for scrolling the list.
  final ScrollController scrollController;

  /// Called when the user begins asking.
  final VoidCallback onAskingStarted;

  /// Called when the user ends asking.
  final VoidCallback onAskingEnded;

  /// Called when a suggestion is selected.
  final OnSuggestionSelected onSuggestionSelected;

  /// The number of columns to use for displaying suggestions.
  final int columnCount;

  /// Constructor.
  SuggestionList({
    Key key,
    this.scrollController,
    this.onAskingStarted,
    this.onAskingEnded,
    this.onSuggestionSelected,
    this.columnCount: 1,
  })
      : super(key: key);

  @override
  SuggestionListState createState() => new SuggestionListState();
}

/// Manages the asking state for the [SuggestionList].
class SuggestionListState extends State<SuggestionList>
    with TickerProviderStateMixin {
  final TextEditingController _askTextController = new TextEditingController();
  final FocusNode _askFocusNode = new FocusNode();
  bool _asking = false;
  Suggestion _selectedSuggestion;
  DateTime _lastBuildTime;
  AnimationController _fadeInAnimation;
  CurvedAnimation _curvedFadeInAnimation;

  @override
  void initState() {
    super.initState();
    _fadeInAnimation = new AnimationController(
      vsync: this,
      value: 0.0,
      duration: _kFadeInDuration,
    );
    _curvedFadeInAnimation = new CurvedAnimation(
      parent: _fadeInAnimation,
      curve: Curves.fastOutSlowIn,
    );
    _askFocusNode.addListener(() {
      print('ask focus changed: ${_askFocusNode.hasFocus}');
      if (_askFocusNode.hasFocus) {
        if (_asking == false) {
          setState(() {
            _asking = true;
          });
          SuggestionModel.of(context).asking = _asking;
          widget.onAskingStarted?.call();
        }
      }
    });
  }

  /// Clears the ask text.
  void _clear() {
    _askTextController.clear();
    SuggestionModel.of(context).askText = null;
  }

  /// Clears the last selected suggestion.  The selected suggestion isn't drawn
  /// in favor of a splash transition drawing it.
  void resetSelection() {
    setState(() {
      _selectedSuggestion = null;
    });
  }

  /// Stops asking and clears the the ask text.
  void stopAsking() {
    _askFocusNode.unfocus();
    _clear();
    if (!_asking) {
      return;
    }
    setState(() {
      _asking = false;
      SuggestionModel.of(context).asking = _asking;
      widget.onAskingEnded?.call();
    });
  }

  /// Selects the first suggestion in the list as if it had been tapped.
  void selectFirstSuggestions() {
    List<Suggestion> suggestions = SuggestionModel.of(context).suggestions;
    if (suggestions.isNotEmpty) {
      _onSuggestionSelected(suggestions[0]);
    }
  }

  @override
  Widget build(BuildContext context) => new Overlay(
        initialEntries: <OverlayEntry>[
          new OverlayEntry(
            builder: (BuildContext context) => new Stack(
                  fit: StackFit.passthrough,
                  children: <Widget>[
                    new Positioned(
                      top: 0.0,
                      left: 0.0,
                      right: 0.0,
                      height: kAskHeight,
                      child: new GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          FocusScope.of(context).requestFocus(_askFocusNode);
                        },
                        child: new Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: <Widget>[
                            // Image.
                            new Padding(
                              padding: const EdgeInsets.only(
                                right: 16.0,
                                left: 32.0,
                                top: 32.0,
                                bottom: 32.0,
                              ),
                              child:
                                  new Image.asset(_kImage, fit: BoxFit.cover),
                            ),
                            // Ask Anything text field.
                            new Expanded(
                              child: new Align(
                                alignment: FractionalOffset.centerLeft,
                                child: new Material(
                                  color: Colors.transparent,
                                  child: new TextField(
                                    decoration: new InputDecoration(
                                      hintText: 'Ask for anything',
                                      hintStyle: new TextStyle(
                                        fontSize: 16.0,
                                        color: Colors.grey[600],
                                      ),
                                      hideDivider: true,
                                    ),
                                    style: new TextStyle(
                                      fontSize: 16.0,
                                      color: Colors.grey[600],
                                    ),
                                    focusNode: _askFocusNode,
                                    controller: _askTextController,
                                    onChanged: (String text) {
                                      SuggestionModel.of(context).askText =
                                          text;
                                    },
                                    onSubmitted: (String text) {
                                      // Select the first suggestion on text commit (ie.
                                      // Pressing enter or tapping 'Go').
                                      List<Suggestion> suggestions =
                                          SuggestionModel
                                              .of(context)
                                              .suggestions;
                                      if (suggestions.isNotEmpty) {
                                        _onSuggestionSelected(
                                            suggestions.first);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    new Positioned(
                      top: kAskHeight,
                      left: 0.0,
                      right: 0.0,
                      bottom: 0.0,
                      child: new ScopedModelDescendant<SuggestionModel>(
                        builder: (
                          BuildContext context,
                          Widget child,
                          SuggestionModel suggestionModel,
                        ) {
                          _lastBuildTime = new DateTime.now();
                          _fadeInAnimation.value = 0.0;
                          _fadeInAnimation.forward();
                          return widget.columnCount == 3
                              ? _createThreeColumnBlock(
                                  suggestionModel.suggestions)
                              : widget.columnCount == 2
                                  ? _createTwoColumnBlock(
                                      suggestionModel.suggestions)
                                  : _createSingleColumnBlock(
                                      suggestionModel.suggestions,
                                    );
                        },
                      ),
                    ),
                  ],
                ),
          ),
        ],
      );

  Widget _createSingleColumnBlock(List<Suggestion> suggestions) => new Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8.0,
        ),
        child: new ListView(
          controller: widget.scrollController,
          children: suggestions
              .map((Suggestion suggestion) => _createSuggestion(suggestion))
              .toList(),
        ),
      );

  Widget _createTwoColumnBlock(List<Suggestion> suggestions) {
    int minSuggestionsPerColumn = (suggestions.length / 2).floor();
    int additionalLeftSuggestions = suggestions.length % 2;
    int additionalRightSuggestions =
        (suggestions.length + additionalLeftSuggestions) % 2;
    List<Suggestion> leftSuggestions = new List<Suggestion>.generate(
      minSuggestionsPerColumn + additionalLeftSuggestions,
      (int index) => suggestions[index * 2],
    );
    List<Suggestion> rightSuggestions = new List<Suggestion>.generate(
      minSuggestionsPerColumn + additionalRightSuggestions,
      (int index) => suggestions[index * 2 + 1],
    );
    return new Align(
      alignment: FractionalOffset.topCenter,
      child: new ConstrainedBox(
        constraints: new BoxConstraints(maxWidth: 960.0),
        child: new ListView.builder(
          controller: widget.scrollController,
          itemCount: leftSuggestions.length,
          itemBuilder: (BuildContext context, int index) => new Row(
                children: <Widget>[
                  new Container(height: 0.0, width: 24.0),
                  new Expanded(
                      child: _createSuggestion(leftSuggestions[index])),
                  new Container(height: 0.0, width: 24.0),
                  new Expanded(
                    child: index < rightSuggestions.length
                        ? _createSuggestion(rightSuggestions[index])
                        : new Offstage(offstage: true),
                  ),
                  new Container(height: 0.0, width: 24.0),
                ],
              ),
        ),
      ),
    );
  }

  Widget _createThreeColumnBlock(List<Suggestion> suggestions) {
    int minSuggestionsPerColumn = (suggestions.length / 3).floor();
    int additionalLeftSuggestions = suggestions.length % 3 > 0 ? 1 : 0;
    int additionalMiddleSuggestions = suggestions.length % 3 > 1 ? 1 : 0;
    List<Suggestion> leftSuggestions = new List<Suggestion>.generate(
      minSuggestionsPerColumn + additionalLeftSuggestions,
      (int index) => suggestions[index * 3],
    );
    List<Suggestion> middleSuggestions = new List<Suggestion>.generate(
      minSuggestionsPerColumn + additionalMiddleSuggestions,
      (int index) => suggestions[index * 3 + 1],
    );
    List<Suggestion> rightSuggestions = new List<Suggestion>.generate(
      minSuggestionsPerColumn,
      (int index) => suggestions[index * 3 + 2],
    );
    return new Align(
      alignment: FractionalOffset.topCenter,
      child: new ConstrainedBox(
        constraints: new BoxConstraints(maxWidth: 1440.0),
        child: new ListView.builder(
          controller: widget.scrollController,
          itemCount: leftSuggestions.length,
          itemBuilder: (BuildContext context, int index) => new Row(
                children: <Widget>[
                  new Container(height: 0.0, width: 24.0),
                  new Expanded(
                    child: _createSuggestion(leftSuggestions[index]),
                  ),
                  new Container(height: 0.0, width: 24.0),
                  new Expanded(
                    child: index < middleSuggestions.length
                        ? _createSuggestion(middleSuggestions[index])
                        : new Offstage(offstage: true),
                  ),
                  new Container(height: 0.0, width: 24.0),
                  new Expanded(
                    child: index < rightSuggestions.length
                        ? _createSuggestion(rightSuggestions[index])
                        : new Offstage(offstage: true),
                  ),
                  new Container(height: 0.0, width: 24.0),
                ],
              ),
        ),
      ),
    );
  }

  void _onSuggestionSelected(Suggestion suggestion) {
    if (new DateTime.now().difference(_lastBuildTime) < _kFadeInDuration) {
      return;
    }
    switch (suggestion.selectionType) {
      case SelectionType.launchStory:
      case SelectionType.modifyStory:
      case SelectionType.closeSuggestions:
        setState(() {
          _selectedSuggestion = suggestion;
        });
        // We pass the bounds of the suggestion w.r.t.
        // global coordinates so it can be mapped back to
        // local coordinates when it's displayed in the
        // SelectedSuggestionOverlay.
        RenderBox box =
            new GlobalObjectKey(suggestion).currentContext.findRenderObject();
        widget.onSuggestionSelected(
          suggestion,
          box.localToGlobal(Offset.zero) & box.size,
        );
        break;
      case SelectionType.doNothing:
      default:
        break;
    }
  }

  Widget _createSuggestion(Suggestion suggestion) => new RepaintBoundary(
        child: new FadeTransition(
          opacity: _curvedFadeInAnimation,
          child: new Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 12.0,
            ),
            child: new SuggestionWidget(
              key: new GlobalObjectKey(suggestion),
              visible: _selectedSuggestion?.id != suggestion.id,
              suggestion: suggestion,
              onSelected: () => _onSuggestionSelected(suggestion),
            ),
          ),
        ),
      );

  /// Determines the width of a suggestion in the suggestion list.
  static double getSuggestionWidth(
    double maxWidth,
    int suggestionColumnCount,
  ) {
    switch (suggestionColumnCount) {
      case 1:
        return maxWidth - (2 * 8.0);
      case 2:
        return (math.min(960.0, maxWidth) - (3 * 24.0)) / 2.0;
      case 3:
        return (math.min(1440.0, maxWidth) - (4 * 24.0)) / 3.0;
      default:
        return 300.0;
    }
  }

  /// Determines the horizontal margin of suggestions in the suggestion list.
  static double getSuggestionHorizontalMargin(
    int suggestionColumnCount,
  ) {
    switch (suggestionColumnCount) {
      case 1:
        return 8.0;
      default:
        return 24.0;
    }
  }
}
