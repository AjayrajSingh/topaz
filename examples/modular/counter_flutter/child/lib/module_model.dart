// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show json;

import 'package:lib.logging/logging.dart';
import 'package:fuchsia.fidl.modular/modular.dart';
import 'package:lib.widgets/modular.dart';

const String _kCounterKey = 'counter';

/// The [ModuleModel] class for this counter child module, which encapsulates
/// how this module interacts with Fuchsia's modular framework.
class CounterChildModuleModel extends ModuleModel {
  /// Creates a new instance.
  ///
  /// Setting the [watchAll] value to `true` makes sure that you get notified
  /// by [Link] service, even with the changes are made by this model.
  CounterChildModuleModel() : super(watchAll: true);

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

  /// Called when the [Link] data changes.
  @override
  void onNotify(String encodedJson) {
    log.info(encodedJson);
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
