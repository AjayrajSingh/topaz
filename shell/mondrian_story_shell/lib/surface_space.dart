// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import 'tree.dart';
import 'positioned_builder.dart';
import 'surface_form.dart';
import 'surface_instance.dart';

const SpringDescription _kSimSpringDescription = const SpringDescription(
  mass: 1.0,
  springConstant: 120.0,
  damping: 19.0,
);

SimulationBuilder _dimSim() => (double start, double velocity, double end) =>
    new SpringSimulation(
      _kSimSpringDescription,
      start,
      end,
      velocity,
      tolerance: const Tolerance(distance: 1e-2, time: 1e-2, velocity: 1e-2),
    );

/// Spaces determine how things move, and how they can be manipulated
class SurfaceSpace extends StatefulWidget {
  /// Construct a SurfaceSpace with these forms
  SurfaceSpace({@required this.forms});

  /// The forms inside this space
  final Forest<SurfaceForm> forms;

  @override
  State<SurfaceSpace> createState() => new _SurfaceSpaceState();
}

class _SurfaceSpaceState extends State<SurfaceSpace>
    with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    List<SurfaceForm> flattened = <SurfaceForm>[];
    for (Tree<SurfaceForm> formTree in widget.forms) {
      flattened.addAll(formTree.values);
    }
    flattened
        .sort((SurfaceForm a, SurfaceForm b) => b.depth.compareTo(a.depth));
    // Order by depth
    // Create SingleChild widgets, add to stack
    return new Stack(
      fit: StackFit.expand,
      children: flattened
          .map((SurfaceForm f) => new SurfaceInstance(
                form: f,
                positionSim: new Sim2DAnimation(
                  vsync: this,
                  xSim: _dimSim(),
                  ySim: _dimSim(),
                  target: f.position.center,
                )..addStatusListener((AnimationStatus status) {
                    if (status == AnimationStatus.completed) {
                      f.onPositioned();
                    }
                  }),
                sizeSim: new Sim2DAnimation(
                  vsync: this,
                  xSim: _dimSim(),
                  ySim: _dimSim(),
                  target: f.position.size.bottomRight(Offset.zero),
                ),
              ))
          .toList(),
    );
  }
}
