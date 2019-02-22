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
  static const String _actionJsonKey = 'action';
  static const String _keyJsonKey = 'key';
  static const String _defaultTransitionKey = 'default_transition';
  static const String _resultsKey = 'result';

  String _defaultTransition;

  final Map<String, String> _results = {};

  /// A unique identifier within the scope of the defined flow.
  final String key;

  /// The action associated with the [Step].
  final String action;

  Step(this.key, this.action, {Map<String, dynamic> results}) {
    results?.forEach((key, action) => _results[key] = action);
  }

  factory Step.fromJson(Map<String, dynamic> json) {
    final Step step = Step(json[_keyJsonKey], json[_actionJsonKey],
        results: json[_resultsKey])
      ..defaultTransition = json[_defaultTransitionKey];

    return step;
  }

  Map<String, dynamic> toJson() => {
        _keyJsonKey: key,
        _actionJsonKey: action,
        _defaultTransitionKey: _defaultTransition,
        _resultsKey: _results,
      };

  /// Returns the next [Step] to proceed to based on the [result].
  String getNext([String result]) {
    final String searchVal = _results[result];
    return searchVal != null || _defaultTransition == null
        ? searchVal
        : _defaultTransition;
  }

  /// Sets the default [Step] to move if no match is found in the set results.
  set defaultTransition(String key) => _defaultTransition = key;

  /// Adds a transition from this [Step] for a given [resultCode]. When this
  /// step returns, the mappings specified here are used to determine the next
  /// [Step] to visit.
  void addResult(String resultCode, String resultKey) {
    _results[resultCode] = resultKey;
  }

  @override
  String toString() => 'key: $key defaultTransition:$_defaultTransition}';

  /// Returns all next steps. Used by syllabus to discover all routes
  Set<String> get nextSteps {
    final Set<String> steps = Set<String>.from(_results.values);

    if (_defaultTransition != null) {
      steps.add(_defaultTransition);
    }

    return steps;
  }

  @override
  int get hashCode => key.hashCode;

  @override
  bool operator ==(Object other) => other is Step && other.key == key;
}
