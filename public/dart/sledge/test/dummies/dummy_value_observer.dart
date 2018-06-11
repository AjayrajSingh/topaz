// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO: try to stop ignoring "implementation_imports".
// ignore_for_file: implementation_imports

import 'package:sledge/src/document/value_observer.dart';

class DummyValueObserver implements ValueObserver {
  @override
  void valueWasChanged() {}
}
