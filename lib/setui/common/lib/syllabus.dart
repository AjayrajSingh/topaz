// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'step.dart';

/// A representation of the decision tree consisting of Steps.
class Syllabus {
  final Step _entry;
  final Map<String, Step> _steps = {};

  /// A unique identifier for the syllabus, specified if meant to be one time
  /// use.
  final String singleUseId;

  Syllabus(List<Step> steps, this._entry, [this.singleUseId]) {
    for (Step step in steps) {
      _steps[step.key] = step;
    }
  }

  /// The first step to visit.
  Step get entry => _entry;

  /// Used to retrieve a step associated with the given name.
  Step retrieveStep(String name) => _steps[name];
}
