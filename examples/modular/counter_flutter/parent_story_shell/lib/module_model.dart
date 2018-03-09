// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show json;

import 'package:lib.logging/logging.dart';
import 'package:lib.module.fidl/module_context.fidl.dart';
import 'package:lib.module.fidl._module_controller/module_controller.fidl.dart';
import 'package:lib.story.fidl/link.fidl.dart';
import 'package:lib.surface.fidl/surface.fidl.dart';
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
/// This parent example delegates the layout to the story shell, instead of
/// laying out the child view directly into the screen.
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

    // Start the child module using story shell.
    moduleContext.startModuleInShell(
      'counter_child',
      _kChildModuleUrl,
      null, // null means that the child gets the same link as the parent.
      null,
      _childController.ctrl.request(),
      // Here, we define the surface relationship between the current module and
      // the child module being launched.
      const SurfaceRelation(
        arrangement: SurfaceArrangement.copresent,
        dependency: SurfaceDependency.dependent,
        emphasis: 1.0,
      ),
      true, // The child module is initially focused.
    );
  }

  @override
  void onStop() {
    _childController.ctrl.close();
    super.onStop();
  }

  @override
  void onNotify(String encoded) {
    dynamic decodedJson = json.decode(encoded);
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

  /// Re-focuses the child module.
  void focusChild() {
    _childController.focus();
  }
}
