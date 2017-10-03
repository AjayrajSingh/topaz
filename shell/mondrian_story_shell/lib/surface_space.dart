// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import 'surface_form.dart';
import 'surface_instance.dart';
import 'tree.dart';

/// Spaces determine how things move, and how they can be manipulated
class SurfaceSpace extends StatelessWidget {
  /// Construct a SurfaceSpace with these forms
  SurfaceSpace({@required this.forms});

  /// The forms inside this space
  final Forest<SurfaceForm> forms;

  @override
  Widget build(BuildContext context) => new Stack(
      fit: StackFit.expand,
      // TODO(alangardner): figure out elevation layering
      children: forms
          .reduceForest((SurfaceForm f, Iterable<SurfaceInstance> children) =>
              new SurfaceInstance(form: f, dependents: children.toList()))
          .toList());
}
