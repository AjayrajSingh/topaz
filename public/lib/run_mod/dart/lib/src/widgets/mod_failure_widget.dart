// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// The [ModFailureWidget] is a widget which is displayed when a module has
/// a failure before it can draw its own Widget.
class ModFailureWidget extends StatelessWidget {
  /// The constructur for the [ModFailureWidget]
  const ModFailureWidget({
    Key key,
  }) : super(key: key);

  @override
  //TODO(MS-1508) update this widget to display an error message
  Widget build(BuildContext context) {
    return new Container(
      color: Colors.red,
    );
  }
}
