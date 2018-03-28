// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'logging.dart';

/// Traces the frame rate of an animation.
class FrameRateTracer {
  /// Name of the anmiation for tracing purposes.
  final String name;

  DateTime _animationStart = new DateTime.now();
  int _frames = 0;
  String _currentTargetName;

  /// Constructor.
  FrameRateTracer({this.name});

  /// Starts tracking an animation.
  void start({String targetName}) {
    _currentTargetName = targetName;
    _animationStart = new DateTime.now();
    _frames = 0;
  }

  /// Must be called per tick of the animation.
  void tick() {
    _frames++;
  }

  /// Must be called when the animation is done.  This emits the trace.
  void done() {
    if (_frames == 0) {
      return;
    }
    int microSeconds =
        new DateTime.now().difference(_animationStart).inMicroseconds;
    double frameRate = _frames.toDouble() * 1000000.0 / microSeconds.toDouble();
    String prefix = _currentTargetName?.isEmpty ?? true
        ? '$name'
        : '$name to $_currentTargetName';
    trace(
      '$prefix: ${frameRate.toStringAsPrecision(3)} fps '
          '($_frames/${microSeconds/1000000.0}s)',
    );
  }
}
