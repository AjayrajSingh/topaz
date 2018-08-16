// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// [Step] represents a single destination in a syllabus flow.
///
/// Each [Step] has a unique name, which allows others [Step]s to reference it.
/// A [Step] may have a number of resulting child [Step]s mapped to return
/// result and/or a default one defined. A [Step] is considered the final [Step]
/// if there is no valid [Step] to transition to.
class Step {
  Step _defaultTransition;
  final Map<String, Step> _results = {};

  /// A unique identifier within the scope of the defined flow.
  final String key;

  /// The action associated with the [Step].
  final String action;

  Step(this.key, this.action);

  /// Returns the next [Step] to proceed to based on the [result].
  Step getNext([String result]) {
    final Step searchVal = _results[result];
    return searchVal != null || _defaultTransition == null
        ? searchVal
        : _defaultTransition;
  }

  /// Sets the default [Step] to move if no match is found in the set results.
  set defaultTransition(Step transition) => _defaultTransition = transition;

  /// Adds a transition from this [Step] for a given [resultCode]. When this
  /// step returns, the mappings specified here are used to determine the next
  /// [Step] to visit.
  void addResult(String resultCode, Step result) {
    _results[resultCode] = result;
  }

  /// Returns all next steps. Used by syllabus to discover all routes
  Set<Step> get nextSteps {
    final Set<Step> steps = new Set()..addAll(_results.values);

    if (_defaultTransition != null) {
      steps.add(_defaultTransition);
    }

    return steps;
  }
}
