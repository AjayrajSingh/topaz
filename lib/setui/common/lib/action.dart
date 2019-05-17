// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

import 'step.dart';

/// The types of errors that can be encountered while a step is running.
enum Error { undefined }

/// Interface for sending results from [Action] clients.
/// ignore: one_member_abstracts
abstract class ActionResultSender {
  void sendResult(String result);
}

/// Interface for receiving results from an [Action].
/// ignore: one_member_abstracts
abstract class ActionResultReceiver {
  void onResult(ActionResult result);
}

/// Instructions for assembling an [Action].
abstract class Blueprint {
  /// The name of the action
  final String key;

  /// A description of the action. Used for logging and debugging purposes
  final String description;

  /// Default constructor requires at least the action name
  Blueprint(this.key, this.description);

  /// Creates an instance of the action for use
  Action assemble(Step step, ActionResultReceiver callback);
}

/// A running action instance generated from a [Blueprint].
abstract class Action<T extends Blueprint> {
  final T blueprint;
  final Step step;
  final ActionResultReceiver callback;

  Action(this.step, this.blueprint, this.callback);

  /// Called by client to return result
  void onResult(String result) {
    callback.onResult(ActionResult(step, result));
  }

  /// Called by owner to start the action
  void launch();
}

/// A store for action names mapped to steps.
class Roster {
  final Map<String, Blueprint> _plans = {};

  /// Adds the specified [Blueprint] to the roster using its action name
  /// as the key.
  void add(Blueprint blueprint) {
    _plans[blueprint.key] = blueprint;
  }

  /// Searches for a [Blueprint] matching the [Step]'s action and then assembles
  /// an [Action] with the given [ActionResultReceiver].
  Action getAction(Step step, ActionResultReceiver callback) {
    return _plans.containsKey(step.action)
        ? _plans[step.action].assemble(step, callback)
        : null;
  }

  @visibleForTesting
  int get actionCount => _plans.length;
}

/// A PODO for capturing a step's execution results.
class ActionResult {
  /// The associated Step.
  final Step step;

  /// The return code from the step that can be used to map to the next step
  /// to transition to. Note this can be null.
  final String code;

  /// The type of error if one is encountered during the step. In a normal
  /// expected flow, this should be null.
  final Error error;

  ActionResult(this.step, this.code, [this.error]);
}
