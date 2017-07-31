// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';
import 'package:sysui_widgets/ticking_height_state.dart';

import 'peek_model.dart';
import 'size_model.dart';

const double _kStartOverlayTransitionHeight = 28.0;

/// The distance the top right corner is inset when peeking.  When hiding, the
/// top left corner will inset the same distance as the overlay becomes
/// fully hidden.
const double _kAngleOffsetY = 0.0;

/// Builds the child which floats vertically above this overlay.
typedef Widget ChildAboveBuilder(BuildContext context, double overlayHeight);

/// A bottom aligned overlay which peeks up over the bottom.
class PeekingOverlay extends StatefulWidget {
  /// The amount the overlay should peek above the bottom of its parent when
  /// hiding.
  final double peekHeight;

  /// The height to allow vertical drags to open/close the overlay.
  final double dragHandleHeight;

  /// The widget to display within the overlay.
  final Widget child;

  /// Called when the overlay is hidden.
  final VoidCallback onHide;

  /// Called when the overlay is shown.
  final VoidCallback onShow;

  /// Constructor.
  PeekingOverlay({
    Key key,
    this.peekHeight: _kStartOverlayTransitionHeight,
    this.dragHandleHeight,
    this.onHide,
    this.onShow,
    this.child,
  })
      : super(key: key);

  @override
  PeekingOverlayState createState() => new PeekingOverlayState();
}

/// A [TickingHeightState] that changes its height to [minHeight] via [hide] and\
/// [maxHeight] via [show].
///
/// As the [height] increases above [minHeight] [PeekingOverlay.child] will grow
/// up from the bottom.  The area not given to that [Widget] will gradually
/// darken.
///
/// The [createWidget] [Widget] will be clipped to [height] but will be given
/// [maxHeight] to be laid out in.
class PeekingOverlayState extends TickingHeightState<PeekingOverlay> {
  static final double _kSnapVelocityThreshold = 500.0;
  bool _hiding = true;
  bool _peeking;

  @override
  void initState() {
    super.initState();
    maxHeight = widget.peekHeight;
    _setPeeking(true);
  }

  @override
  void didUpdateWidget(PeekingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.peekHeight != widget.peekHeight) {
      minHeight = _peeking ? widget.peekHeight : 0.0;
      if (_hiding) {
        setHeight(minHeight);
      } else {
        setHeight(maxHeight);
      }
    }
  }

  /// Hides the overlay.
  void hide() {
    widget.onHide?.call();
    _hiding = true;
    setHeight(minHeight);
  }

  /// Shows the overlay.
  void show() {
    widget.onShow?.call();
    _hiding = false;
    setHeight(maxHeight);
  }

  /// If [peeking] is true, the overlay will pop up itself over the bottom of
  /// its parent by the [PeekingOverlay.peekHeight].
  void _setPeeking(bool peeking) {
    if (peeking != _peeking) {
      _peeking = peeking;
      minHeight = _peeking ? widget.peekHeight : 0.0;
      hide();
    }
  }

  /// Returns true if the overlay is currently hiding.
  bool get hiding => _hiding;

  /// Updates the overlay as if it was being dragged vertically.
  void onVerticalDragUpdate(DragUpdateDetails details) =>
      setHeight(height - details.primaryDelta, force: true);

  /// Updates the overlay as if it was finished being dragged vertically.
  void onVerticalDragEnd(DragEndDetails details) =>
      snap(details.velocity.pixelsPerSecond.dy);

  /// Snaps the overlay open (showing) or closed (hiding) based on the vertical
  /// velocity occuring at the time a vertical drag finishes.
  void snap(double verticalVelocity) {
    if (verticalVelocity < -_kSnapVelocityThreshold) {
      show();
    } else if (verticalVelocity > _kSnapVelocityThreshold) {
      hide();
    } else if (height - minHeight < maxHeight - height) {
      hide();
    } else {
      show();
    }
  }

  @override
  Widget build(BuildContext context) => new ScopedModelDescendant<PeekModel>(
        builder: (BuildContext context, Widget child, PeekModel model) {
          // This triggers the height animation for this overlay if peek has
          // changed.
          _setPeeking(model.peek);
          return child;
        },
        child: new Stack(
          fit: StackFit.expand,
          children: <Widget>[
            new Offstage(
              offstage: hiding,
              child: new Listener(
                onPointerUp: (_) => hide(),
                behavior: HitTestBehavior.opaque,
              ),
            ),
            new Positioned(
              left: 0.0,
              right: 0.0,
              bottom: 0.0,
              height: height,
              child: new ScopedModelDescendant<SizeModel>(
                  builder: (
                    BuildContext context,
                    Widget child,
                    SizeModel sizeModel,
                  ) {
                    // Set maxHeight appropriately.
                    double targetMaxHeight = 0.8 * sizeModel.screenSize.height;
                    if (maxHeight != targetMaxHeight &&
                        targetMaxHeight != 0.0) {
                      maxHeight = targetMaxHeight;
                      if (!hiding) {
                        show();
                      }
                    }

                    return new OverflowBox(
                      minWidth: sizeModel.suggestionListWidth,
                      maxWidth: sizeModel.suggestionListWidth,
                      minHeight: math.max(height, maxHeight),
                      maxHeight: math.max(height, maxHeight),
                      alignment: FractionalOffset.topCenter,
                      child: child,
                    );
                  },
                  child: new Stack(
                    fit: StackFit.passthrough,
                    children: <Widget>[
                      widget.child,
                      new Positioned(
                        top: 0.0,
                        left: 0.0,
                        right: 0.0,
                        height: hiding
                            ? widget.peekHeight
                            : widget.dragHandleHeight,
                        child: new GestureDetector(
                          onVerticalDragUpdate: onVerticalDragUpdate,
                          onVerticalDragEnd: onVerticalDragEnd,
                        ),
                      ),
                    ],
                  )),
            ),
          ],
        ),
      );
}
