// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/widgets.dart';

const RK4SpringDescription _kSimulationDesc =
    const RK4SpringDescription(tension: 10.0, friction: 50.0);
const double _kMinScrollOffset = 0.0;
const double _kMaxScrollOffset = 4000.0;
const int _kNumImages = 100;

/// [Model] that manages the state of the Image Grid Module
class ImageGridModel extends Model {
  final _TracedSpringModel _scrollModel =
      new _TracedSpringModel(springDescription: _kSimulationDesc);

  ImageGridModel() {
    scheduleMicrotask(() {
      _images = generateImages();
      _scrollModel.jump(0.0);

      // Set up auto-scroller behavior.
      _scrollController = new ScrollController();
      _scrollModel
        ..addListener(() {
          if (!_scrollController.hasClients) {
            return;
          }
          _scrollController.jumpTo(_scrollModel.value);
          if (_scrollModel.isDone) {
            _scrollModel.target = _scrollModel.target == _kMinScrollOffset
                ? _kMaxScrollOffset
                : _kMinScrollOffset;
          }
        })
        ..target = _kMaxScrollOffset;
      notifyListeners();
    });
  }

  // Draw some images with circles.
  List<RawImage> generateImages() {
    List<RawImage> images = [];
    for (int i = 0; i < _kNumImages; i++) {
      var recorder = new ui.PictureRecorder();
      var canvas = new Canvas(recorder);
      var color = const Color(0xFF673AB7); // Deep Purple 500
      canvas.drawColor(color, BlendMode.srcOver);

      final paint = new Paint()
        ..color = const Color(0xFFF50057) // Pink A400
        ..style = PaintingStyle.fill;

      canvas.drawCircle(new Offset(250.0, 250.0), 200.0, paint);

      var image = recorder.endRecording().toImage(500, 500);

      images.add(
          new RawImage(image: image, width: 500.0, height: 500.0, scale: 1.0));
    }
    return images;
  }

  /// Images to render
  List<RawImage> get images => _images;
  List<RawImage> _images;

  /// If non-null, controls how the grid is scrolled.
  ScrollController get scrollController => _scrollController;
  ScrollController _scrollController;
}

class _TracedSpringModel extends SpringModel {
  final FrameRateTracer _frameRateTracer =
      new FrameRateTracer(name: 'auto scroll');
  _TracedSpringModel({RK4SpringDescription springDescription})
      : super(springDescription: springDescription);

  @override
  set target(double target) {
    _frameRateTracer.start(targetName: '$target');
    super.target = target;
  }

  @override
  bool handleTick(double elapsedSeconds) {
    _frameRateTracer.tick();
    bool result = super.handleTick(elapsedSeconds);
    if (isDone) {
      _frameRateTracer.done();
    }
    return result;
  }
}
