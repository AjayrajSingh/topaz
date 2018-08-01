// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib_setiu_common/step.dart';

/// A representation of the decision tree consisting of Steps.
class Syllabus {
  final Step _entry;

  /// A unique identifier for the syllabus, specified if meant to be one time
  /// use.
  final String singleUseId;

  Syllabus(this._entry, this.singleUseId);

  /// The first step to visit.
  Step get entry => _entry;

  /// Used to retrieve a starting point. Note that this is used for resuming
  /// flows and is not the typical case. null is returned if no matching
  /// step is found. Note that the step much be reachable from the entry step
  /// to be found.
  Step retrieveStep(String name) {
    final Set<Step> encounteredSteps = new Set();
    final List<Step> pendingSteps = [entry];

    while (pendingSteps.isNotEmpty) {
      final Step target = pendingSteps.removeAt(0);

      if (encounteredSteps.contains(target)) {
        continue;
      }

      if (target.key == name) {
        return target;
      }

      encounteredSteps.add(target);
      pendingSteps.addAll(target.nextSteps);
    }

    return null;
  }
}
