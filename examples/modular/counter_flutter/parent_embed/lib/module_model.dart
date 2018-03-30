// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show json;

import 'package:fidl/fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:fuchsia.fidl.modular/modular.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:fuchsia.fidl.views_v1_token/views_v1_token.dart';
import 'package:lib.widgets/modular.dart';

const String _kChildModuleUrl = 'example_flutter_counter_child';
const String _kCounterKey = 'counter';
const String _kJsonSchema = '''
{
  "\$schema": "http://json-schema.org/draft-04/schema#",
  "type": "object",
  "properties": {
     "$_kCounterKey": {
        "type": "integer"
     }
   },
   "additionalProperties" : false,
   "required": [
      "$_kCounterKey"
   ]
}
''';

/// The [ModuleModel] class for this counter child module, which encapsulates
/// how this module interacts with Fuchsia's modular framework.
///
/// This parent example uses direct embedding to layout the child view into the
/// screen manually.
class CounterParentModuleModel extends ModuleModel {
  /// Creates a new instance.
  ///
  /// Setting the [watchAll] value to `true` makes sure that you get notified
  /// by [Link] service, even with the changes are made by this model.
  CounterParentModuleModel() : super(watchAll: true);

  /// In-memory counter value.
  int _counter = 0;

  /// Gets the counter value.
  int get counter => _counter;

  /// Sets the counter value and call [notifyListeners()] to redraw the
  /// [ScopedModelDescendant]s of this model.
  set counter(int value) {
    _counter = value;
    notifyListeners();
  }

  ChildViewConnection _connection;

  /// The [ChildViewConnection] that holds the [ViewOwner] of the child module.
  ChildViewConnection get connection => _connection;

  final ModuleControllerProxy _childController = new ModuleControllerProxy();

  @override
  void onReady(
    ModuleContext moduleContext,
    Link link,
  ) {
    super.onReady(moduleContext, link);

    // Set a JSON schema to the main link of this module. If an update violates
    // the schema, this only creates debug log output.
    link.setSchema(_kJsonSchema);

    // Start the child module and obtain the ViewOwner.
    InterfacePair<ViewOwner> viewOwnerPair = new InterfacePair<ViewOwner>();
    moduleContext.startModuleDeprecated(
      'counter_child',
      _kChildModuleUrl,
      null, // null means that the child gets the same link as the parent.
      null,
      _childController.ctrl.request(),
      viewOwnerPair.passRequest(),
    );

    // Create a child view connection, so that it can be laid out in the screen.
    _connection = new ChildViewConnection(viewOwnerPair.passHandle());
    notifyListeners();
  }

  @override
  void onStop() {
    _childController.ctrl.close();
    super.onStop();
  }

  /// Called when the [Link] data changes.
  @override
  void onNotify(String encodedJson) {
    dynamic decodedJson = json.decode(encodedJson);
    if (decodedJson is Map<String, dynamic> &&
        decodedJson[_kCounterKey] is int) {
      counter = decodedJson[_kCounterKey];
    }
  }

  /// Increments the counter value by writing the new value to the [Link].
  ///
  /// Note that this method does not increment the [_counter] value directly.
  /// Instead, we update the [_counter] value upon [onNotify()] callback, which
  /// will be caused by writing this new value to the [Link].
  ///
  /// This creates a unidirectional data-flow similar to flux, and makes sure
  /// that the [_counter] value and the [Link] value are always in sync.
  void increment() {
    log.info('increment');
    link.set(<String>[_kCounterKey], json.encode(counter + 1));
  }

  /// Decrements the counter value by writing the new value to the [Link].
  void decrement() {
    log.info('decrement');
    link.set(<String>[_kCounterKey], json.encode(counter - 1));
  }
}
