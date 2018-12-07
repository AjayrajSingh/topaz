// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: unused_import
import 'package:fidl_fidl_test_before/fidl_async.dart' as before;
import 'package:fidl_fidl_test_during/fidl_async.dart' as during;

class AddMethodImpl extends before.AddMethod {
  @override
  Future<void> existingMethod() async {}
}

class RemoveMethodImpl extends before.RemoveMethod {
  @override
  Future<void> existingMethod() async {}
  @override
  Future<void> oldMethod() async {}
}

class AddEventImpl extends before.AddEvent {
  @override
  Future<void> existingMethod() async {}
}

class RemoveEventImpl extends before.RemoveEvent {
  @override
  Future<void> existingMethod() async {}
  @override
  Stream<void> get oldEvent async* {}
}
