// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'step.dart';

/// Invoked when an action has completed.
typedef ActionCallback = void Function(ActionResult);

/// Used to obtain an action for the given step.
typedef RetrieveAction = LaunchAction Function(Step);

/// Invoked to begin an action.
typedef LaunchAction = void Function(ActionCallback);

// Called to send result back to the action handler.
typedef SendResult = void Function(String);

/// The types of errors that can be encountered while a step is running.
enum Error { undefined }

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
