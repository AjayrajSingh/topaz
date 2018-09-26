// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

import 'module_state_exception.dart';

/// An [Intent] is a fundamental building block of module development.
/// Modules will either be started with an intent or will receive an
/// intent after they have been launched. It is up to the module author
/// to decide how to respond to the intents.
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
///         },
///         {
///           "name": "dog",
///           "type": "dog-type"
///         }
///       ]
///     }
///   ]
/// }
/// ```
class Intent {
  final Map<String, IntentParameter> _parameters = {};

  /// The action which triggered this action. This value can be an empty
  /// string if the Intent came from the system launcher.
  final String action;

  /// The default constructor for an [Intent].
  Intent({
    @required this.action,
    List<IntentParameter> parameters = const [],
  }) : assert(action != null) {
    for (final parameter in parameters) {
      _parameters[parameter.name] = parameter;
    }
  }

  /// Returns the [IntentParameter] for the given name.
  /// This method will throw a [ModuleStateException] if there is no
  /// parameter with the given name in the intent.
  ///
  /// The underlying framework guarantees that an Intent cannot be
  /// resolved if it does not fully satisfy the parameters indicated
  /// by the module manifest.
  IntentParameter getParameter(String name) {
    return _parameters[name] ??
        () {
          throw ModuleStateException(
              'The Intent for action [$action] does not have an IntentParameter '
              'with the name [$name]. An intent will only be fulfilled if all '
              'required parameters are present. To resolve this issue add '
              'the parameter to your module manifest file.');
        }();
  }
}

/// An [IntentParameter] is an object which is included in the [Intent].
/// The parameter will hold data which the module has requested in the
/// module manifest file. [IntentParameter]s can be watched if they are
/// of the type of parameter that will constantly update their values
/// or a single value can be retrieved if they are not expected to get
/// a stream of data.
abstract class IntentParameter {
  /// The name of the parameter which maps to the name field in the
  /// module manifest.
  String get name;

  /// Returns a [Stream] which can be watched to receive continuous updates.
  /// The [codec] will be used to translate the incoming bytes to a dart object.
  Stream<T> watchData<T>(IntentParameterCodec<T> codec);

  /// Returns the value associated with this [IntentParameter]. The [codec]
  /// will be used to translate the incoming bytes to a dart object.
  Future<T> getValue<T>(IntentParameterCodec<T> codec);
}

/// The [EntityIntentParameter] is a concrete implementation of the
/// [IntentParameter] class which is to be used when the intent parameter's
/// data is of type entity.
class EntityIntentParameter implements IntentParameter {
  @override
  final String name;

  /// The entity reference backing the entity
  ///
  /// note: this field is currently unused but will be needed when watch/get
  /// are implemented.
  // ignore: unused_field
  final String _entityReference;

  /// The default constructor for the [EntityIntentParameter].
  EntityIntentParameter({
    @required this.name,
    @required String entityReference,
  })  : assert(name != null),
        assert(entityReference != null),
        _entityReference = entityReference;

  @override
  Future<T> getValue<T>(IntentParameterCodec<T> codec) {
    throw Exception('not implemented yet');
  }

  @override
  Stream<T> watchData<T>(IntentParameterCodec<T> codec) {
    throw Exception('not implemented yet');
  }
}

/// Only here to make the compiler happy until we figure out the signature
class IntentParameterCodec<T> {}
