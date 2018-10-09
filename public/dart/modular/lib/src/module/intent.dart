// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl;
import 'package:meta/meta.dart';

import '_fidl_transformers.dart';
import 'intent_parameter.dart';
import 'module_state_exception.dart';

/// An [Intent] is a fundamental building block of module development.
/// Modules will either be started with an intent or will receive an
/// intent after they have been launched. It is up to the module author
/// to decide how to respond to the intents that they receive.
///
/// A module will only receive intents which have been registered in their
/// module manifest file. A special case is when they are launched by the
/// system launcher in which case the action will be an empty string.
///
/// An example manifest which handles multiple intents would look like:
/// ```
/// {
///   "@version": 2,
///   "binary": "my_binary",
///   "suggestion_headline": "My Suggesting Headline",
///   "intent_filters": [
///     {
///       "action": "com.my-pets-app.show_cats",
///       "parameters": [
///         {
///           "name": "cat",
///           "type": "cat-type"
///         }
///       ]
///     },
///     {
///       "action": "com.my-pets-app.show_dogs",
///       "parameters": [
///         {
///           "name": "dog",
///           "type": "dog-type"
///         },
///         {
///           "name": "owner",
///           "type": "person-type"
///         }
///       ]
///     }
///   ]
/// }
/// ```
class Intent extends fidl.Intent {
  /// Creates an [Intent] that is used to start
  /// a module which can handle the specified action.
  /// If an explicit handler is not set the modular framework
  /// will search for an appropriate handler for the given action.
  Intent({
    @required String action,
    String handler,
  })  : assert(action != null),
        super(
          action: action,
          handler: handler,
          parameters: [],
        );

  /// Appends a [fidl.IntentParameter] to the intent's parameters containing
  /// the [reference] as its data value and the [name] as its name value.
  void addParameterFromEntityReference(String name, String reference) =>
      _addParameter(
          name, fidl.IntentParameterData.withEntityReference(reference));

  /// Returns the [IntentParameter] for the given name.
  /// This method will throw a [ModuleStateException] if there is no
  /// parameter with the given name in the intent.
  ///
  /// The underlying framework guarantees that an Intent cannot be
  /// resolved if it does not fully satisfy the parameters indicated
  /// by the module manifest.
  IntentParameter getParameter(String name) {
    final parameter = parameters.firstWhere((p) => p.name == name,
        orElse: () => throw ModuleStateException(
            'The Intent for action [$action] does not have an IntentParameter '
            'with the name [$name]. An intent will only be fulfilled if all '
            'required parameters are present. To resolve this issue add '
            'the parameter to your module manifest file.'));

    return convertFidlIntentParameterToIntentParameter(parameter);
  }

  void _addParameter(String name, fidl.IntentParameterData parameterData) =>
      parameters.add(fidl.IntentParameter(name: name, data: parameterData));
}
