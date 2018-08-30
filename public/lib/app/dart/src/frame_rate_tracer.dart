// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_cobalt/fidl.dart';
import 'package:meta/meta.dart';

import 'logging.dart';

/// Traces the frame rate of an animation.
class FrameRateTracer {
  /// Name of the animation for tracing purposes.
  final String name;

  /// Optional cobalt logger.  If not null the frame rate will be logged as
  /// an observation to cobalt.
  final Logger cobaltLogger;

  DateTime _animationStart = new DateTime.now();
  int _frames = 0;
  String _currentTargetName;
  int _currentCobaltMetricId;

  /// Constructor.
  FrameRateTracer({@required this.name, this.cobaltLogger});

  /// Starts tracking an animation.
  void start({String targetName, int cobaltMetricId}) {
    _currentTargetName = targetName;
    _currentCobaltMetricId = cobaltMetricId;
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
    if (cobaltLogger != null && _currentCobaltMetricId != null) {
      cobaltLogger.logFrameRate(
        _currentCobaltMetricId,
        0,
        '',
        frameRate,
        (Status2 status) {
          if (status != Status2.ok) {
            log.warning(
              'Failed to observe frame rate metric '
                  '$_currentCobaltMetricId: $status. ',
            );
          }
        },
      );
    }
  }
}
