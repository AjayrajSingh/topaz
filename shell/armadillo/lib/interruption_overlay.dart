// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lib.widgets/widgets.dart';

import 'suggestion.dart';
import 'suggestion_list.dart' show OnSuggestionSelected;
import 'suggestion_widget.dart';

const Duration _kInterruptionShowingTimeout =
    const Duration(milliseconds: 3500);

const Duration _kInterruptionExitingTimeout =
    const Duration(milliseconds: 3500);

double _kSpacingBetween = 16.0;
double _kBottomSpacing = 32.0;
double _kHorizontalSpacing = 16.0;
double _kHeight = 100.0;
double _kMaxWidth = 300.0;

enum _RemoveDirection {
  right,
  down,
}

/// Right dismiss with prejudice.
/// Down is dismiss/snooze.
/// Up and left, resist.

/// Displays interruptions.
class InterruptionOverlay extends StatefulWidget {
  /// The height of the peeking overlay this overlay floats vertically above.
  final double overlayHeight;

  /// Called when an interruption is selected.
  final OnSuggestionSelected onSuggestionSelected;

  /// Constructor.
  InterruptionOverlay({
    Key key,
    this.overlayHeight,
    this.onSuggestionSelected,
  })
      : super(key: key);

  @override
  InterruptionOverlayState createState() => new InterruptionOverlayState();
}

/// Tracks the positions of the current interrupts.
class InterruptionOverlayState extends State<InterruptionOverlay> {
  final List<Suggestion> _queuedInterruptions = <Suggestion>[];
  Suggestion _currentInterruption;
  Timer _currentInterruptionTimer;
  final List<Widget> _exitingInterruptionWidgets = <Widget>[];
  BoxConstraints _constraints;

  /// Adds an interruption to the overlay.
  void addInterruption(Suggestion interruption) {
    if (_currentInterruption == null) {
      setState(() {
        _currentInterruption = interruption;
      });
      _startInterruptionTimer();
    } else {
      _queuedInterruptions.add(interruption);
    }
  }

  @override
  Widget build(BuildContext context) => new LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          _constraints = constraints;
          double width = math.min(
            constraints.maxWidth - (2.0 * _kHorizontalSpacing),
            _kMaxWidth,
          );

          List<Widget> stackChildren = new List<Widget>.from(
            _exitingInterruptionWidgets,
          );
          if (_currentInterruption != null) {
            stackChildren.add(
              new SimulatedPositioned(
                key: new ObjectKey(_currentInterruption),
                initRect: new Rect.fromLTWH(
                  constraints.maxWidth - _kHorizontalSpacing - width,
                  constraints.maxHeight + _kBottomSpacing,
                  width,
                  _kHeight,
                ),
                rect: new Rect.fromLTWH(
                  constraints.maxWidth - _kHorizontalSpacing - width,
                  constraints.maxHeight - _kBottomSpacing - _kHeight,
                  width,
                  _kHeight,
                ),
                dragOffsetTransform: (
                  Offset currentOffset,
                  DragUpdateDetails details,
                ) {
                  Offset newOffset = currentOffset + details.delta;
                  return new Offset(
                    details.delta.dx * ((newOffset.dx >= 0.0) ? 1.0 : 0.3),
                    details.delta.dy * ((newOffset.dy >= 0.0) ? 1.0 : 0.3),
                  );
                },
                onDragStart: (_) => _stopInterruptionTimer(),
                onDragEnd: (SimulatedDragEndDetails details) {
                  if (details.offset.dy > 100.0) {
                    _removeInterruption(_RemoveDirection.down, details.offset);
                  } else if (details.offset.dx > 100.0) {
                    _removeInterruption(_RemoveDirection.right, details.offset);
                  } else {
                    _startInterruptionTimer();
                  }
                },
                child: new _FadeInWidget(
                  opacity: 1.0,
                  child: new SuggestionWidget(
                    key: new GlobalObjectKey(_currentInterruption),
                    suggestion: _currentInterruption,
                    onSelected: () => _onSuggestionSelected(
                          _currentInterruption,
                        ),
                  ),
                ),
              ),
            );
          }

          return new Stack(
            overflow: Overflow.visible,
            children: <Widget>[
              new Positioned.fill(
                top: -widget.overlayHeight,
                bottom: widget.overlayHeight,
                child: new Stack(
                  fit: StackFit.expand,
                  overflow: Overflow.visible,
                  children: stackChildren,
                ),
              ),
            ],
          );
        },
      );

  void _removeInterruption(_RemoveDirection direction, Offset offset) {
    Suggestion interruptionToRemove = _currentInterruption;
    assert(interruptionToRemove != null);
    double width = math.min(
      _constraints.maxWidth - (2.0 * _kHorizontalSpacing),
      _kMaxWidth,
    );

    Widget exitingWidget;
    exitingWidget = new SimulatedPositioned(
      key: new ObjectKey(interruptionToRemove),
      rect: new Rect.fromLTWH(
        direction == _RemoveDirection.down
            ? _constraints.maxWidth - _kHorizontalSpacing - width
            : _constraints.maxWidth + _kHorizontalSpacing,
        direction == _RemoveDirection.down
            ? _constraints.maxHeight + _kBottomSpacing
            : _constraints.maxHeight - _kBottomSpacing - _kHeight + offset.dy,
        width,
        _kHeight,
      ),
      onRectReached: () {
        if (mounted) {
          setState(() {
            _exitingInterruptionWidgets.remove(exitingWidget);
          });
        }
      },
      child: new _FadeInWidget(
        opacity: 0.0,
        child: new SuggestionWidget(
          key: new GlobalObjectKey(interruptionToRemove),
          suggestion: interruptionToRemove,
        ),
      ),
    );

    setState(() {
      _exitingInterruptionWidgets.add(exitingWidget);
      if (_queuedInterruptions.isEmpty) {
        _currentInterruption = null;
      } else {
        _currentInterruption = _queuedInterruptions.removeAt(0);
        _startInterruptionTimer();
      }
    });
  }

  void _startInterruptionTimer() {
    _stopInterruptionTimer();
    _currentInterruptionTimer = new Timer(_kInterruptionShowingTimeout, () {
      if (mounted) {
        _removeInterruption(_RemoveDirection.down, Offset.zero);
      }
    });
  }

  void _stopInterruptionTimer() {
    _currentInterruptionTimer?.cancel();
    _currentInterruptionTimer = null;
  }

  void _onSuggestionSelected(Suggestion suggestion) {
    setState(() {
      if (_queuedInterruptions.isEmpty) {
        _currentInterruption = null;
      } else {
        _currentInterruption = _queuedInterruptions.removeAt(0);
        _startInterruptionTimer();
      }
    });

    switch (suggestion.selectionType) {
      case SelectionType.launchStory:
      case SelectionType.modifyStory:
      case SelectionType.closeSuggestions:
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
}

class _FadeInWidget extends StatefulWidget {
  final double opacity;
  final Widget child;

  _FadeInWidget({Key key, this.opacity, this.child}) : super(key: key);

  @override
  _FadeInWidgetState createState() => new _FadeInWidgetState();
}

class _FadeInWidgetState extends State<_FadeInWidget> {
  bool _hasBeenBuilt = false;

  @override
  Widget build(BuildContext context) {
    double opacity = widget.opacity;
    if (!_hasBeenBuilt) {
      scheduleMicrotask(() => setState(() {}));
      _hasBeenBuilt = true;
      opacity = 0.0;
    }

    return new AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 200),
      child: widget.child,
    );
  }
}
