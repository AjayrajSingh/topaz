// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

/// Run an [assert] against the passed in value with an optional message.
void ok({@required bool value, String message}) {
  if (message == null) {
    assert(value);
  } else {
    assert(() {
      if (!value) {
        throw new StateError(message);
      }

      return true;
    });
  }
}
