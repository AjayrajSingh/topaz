// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: unused_import
import 'package:fidl_fidl_test_during/fidl_async.dart' as during;
import 'package:fidl_fidl_test_after/fidl_async.dart' as after;

class AddMethodImpl extends during.AddMethod {
  @override
  Future<void> existingMethod() async {}
  @override
  Future<void> newMethod() async {}
}

class RemoveMethodImpl extends during.RemoveMethod {
  @override
  Future<void> existingMethod() async {}
}

class AddEventImpl extends during.AddEvent {
  @override
  Future<void> existingMethod() async {}
  @override
  Stream<void> get newEvent async* {}
}

class RemoveEventImpl extends during.RemoveEvent {
  @override
  Future<void> existingMethod() async {}
}
