// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show lerpDouble;

import 'package:fidl_fuchsia_modular_auth/fidl.dart';
import 'package:flutter/material.dart';

import 'user_list.dart';
import 'user_picker_base_shell_model.dart';

const double _kRemovalTargetSize = 112.0;

/// Displays a [UserList] a shutdown button, a new user button, the
/// fuchsia logo, and a background image.
class UserPickerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new ScopedModelDescendant<UserPickerBaseShellModel>(
      builder: (
        BuildContext context,
        Widget child,
        UserPickerBaseShellModel model,
      ) {
        return new Material(
          color: Colors.grey[900],
          child: new Stack(
            fit: StackFit.passthrough,
            children: <Widget>[
              /// Add user picker for selecting users and adding new users
              new Align(
                alignment: FractionalOffset.bottomRight,
                child: new RepaintBoundary(
                  child: new UserList(
                    loginDisabled: false,
                  ),
                ),
              ),

              // Add user removal target
              new Align(
                alignment: FractionalOffset.center,
                child: new RepaintBoundary(
                  child: new Container(
                    child: new DragTarget<Account>(
                      onWillAccept: (Account data) => true,
                      onAccept: model.removeUser,
                      builder: (
                        _,
                        List<Account> candidateData,
                        __,
                      ) =>
                          new _UserRemovalTarget(
                            show: model.showingRemoveUserTarget,
                            grow: candidateData.isNotEmpty,
                          ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Displays a removal target for removing users
class _UserRemovalTarget extends StatefulWidget {
  /// Grows the target by some percentage.
  final bool grow;

  /// Shows the target.
  final bool show;

  /// Constructor.
  const _UserRemovalTarget({this.show, this.grow});

  @override
  _UserRemovalTargetState createState() => new _UserRemovalTargetState();
}

class _UserRemovalTargetState extends State<_UserRemovalTarget>
    with TickerProviderStateMixin {
  AnimationController _masterAnimationController;
  AnimationController _initialScaleController;
  CurvedAnimation _initialScaleCurvedAnimation;
  AnimationController _scaleController;
  CurvedAnimation _scaleCurvedAnimation;

  @override
  void initState() {
    super.initState();
    _masterAnimationController = new AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _initialScaleController = new AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _initialScaleCurvedAnimation = new CurvedAnimation(
      parent: _initialScaleController,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.fastOutSlowIn,
    );
    _scaleController = new AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleCurvedAnimation = new CurvedAnimation(
      parent: _scaleController,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.fastOutSlowIn,
    );
    _initialScaleController.addStatusListener((AnimationStatus status) {
      if (!widget.show && _initialScaleController.isDismissed) {
        _masterAnimationController.stop();
      }
    });

    if (widget.show) {
      _masterAnimationController.repeat();
      _initialScaleController.forward();
      if (widget.grow) {
        _scaleController.forward();
      }
    }
  }

  @override
  void didUpdateWidget(_) {
    super.didUpdateWidget(_);
    if (widget.grow) {
      _scaleController.forward();
    } else {
      _scaleController.reverse();
    }
    if (widget.show) {
      _masterAnimationController.repeat();
      _initialScaleController.forward();
    } else {
      _initialScaleController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _initialScaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => new Container(
        child: new AnimatedBuilder(
          animation: _masterAnimationController,
          builder: (BuildContext context, Widget child) => new Transform(
                alignment: FractionalOffset.center,
                transform: new Matrix4.identity().scaled(
                  lerpDouble(1.0, 0.7, _scaleCurvedAnimation.value) *
                      _initialScaleCurvedAnimation.value,
                  lerpDouble(1.0, 0.7, _scaleCurvedAnimation.value) *
                      _initialScaleCurvedAnimation.value,
                ),
                child: new Container(
                  width: _kRemovalTargetSize,
                  height: _kRemovalTargetSize,
                  decoration: new BoxDecoration(
                    borderRadius:
                        new BorderRadius.circular(_kRemovalTargetSize / 2.0),
                    border: new Border.all(color: Colors.white.withAlpha(200)),
                    color: Colors.white.withAlpha(
                        lerpDouble(0, 100.0, _scaleCurvedAnimation.value)
                            .toInt()),
                  ),
                  child: Center(
                    child: const Text(
                      'REMOVE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.0,
                      ),
                    ),
                  ),
                ),
              ),
        ),
      );
}
