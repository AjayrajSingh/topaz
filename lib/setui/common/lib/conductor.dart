// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'action.dart';
import 'step.dart';
import 'syllabus.dart';

/// The [Conductor] controls the overall progression through a [Syllabus]. For
/// each encountered step, it references a [Roster] and launches the
/// appropriate action. Upon result, it progresses to the next appropriate step.
class Conductor implements ActionResultReceiver {
  final Syllabus _syllabus;
  final Roster _roster;

  Conductor(this._syllabus, this._roster);

  /// Begins the flow from the [Syllabus]'s entry point.
  void start() {
    _advance(_syllabus.entry);
  }

  @override
  void onResult(ActionResult result) {
    // On result, proceed to the next step.
    _advance(result.step.getNext(result.code));
  }

  /// Launches the matching action for the given [Step] if defined. Otherwise,
  /// continues to the following default [Step]s until a matching action is
  /// found and launched.
  void _advance(Step step) {
    Action action;

    Step targetStep = step;
    while (targetStep != null && action == null) {
      action = _roster.getAction(targetStep, this);

      if (action == null) {
        targetStep = step.getNext();
      }
    }

    // We cannot proceed further
    if (action == null) {
      return;
    }

    action.launch();
  }
}
