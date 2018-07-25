// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show window;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.widgets/model.dart';

import '../models/inset_manager.dart';
import '../models/surface/surface_graph.dart';
import '../story_shell_impl.dart';
import 'mondrian_logo.dart';
import 'overview.dart';
import 'surface_director.dart';

/// This is used for keeping the reference around.
// ignore: unused_element
StoryShellImpl _storyShellImpl;

/// High level class for choosing between presentations
class Mondrian extends StatefulWidget {
  final SurfaceGraph surfaceGraph;

  /// Constructor
  const Mondrian({@required this.surfaceGraph, Key key}) : super(key: key);

  @override
  MondrianState createState() => new MondrianState();
}

/// State
class MondrianState extends State<Mondrian> {
  bool _showOverview = false;

  @override
  Widget build(BuildContext context) {
    _traceFrame();
    return ScopedModel<SurfaceGraph>(
      model: widget.surfaceGraph,
      child: Stack(
        children: <Widget>[
          _showOverview
              ? Overview()
              : Positioned.fill(child: SurfaceDirector()),
          Positioned(
            left: 0.0,
            bottom: 0.0,
            child: GestureDetector(
              child: Container(
                width: 40.0,
                height: 40.0,
                child: _showOverview ? const MondrianLogo() : null,
              ),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _showOverview = !_showOverview;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

int _frameCounter = 1;
void _traceFrame() {
  Size size = window.physicalSize / window.devicePixelRatio;
  trace('building, size: $size');
  SchedulerBinding.instance.addPostFrameCallback(_frameCallback);
}

void _frameCallback(Duration duration) {
  Size size = window.physicalSize / window.devicePixelRatio;
  trace('frame $_frameCounter, size: $size');
  _frameCounter++;
  if (size.isEmpty) {
    SchedulerBinding.instance.addPostFrameCallback(_frameCallback);
  }
}
