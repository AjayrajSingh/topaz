// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/widgets.dart';

/// The [ModLoadingWidget] is a Widget which is shown as the default loading
/// widget for any module that needs to do asynchronous work before it can
/// draw its own widget.
class ModLoadingWidget extends StatelessWidget {
  /// The constructor for the [ModLoadingWidget]
  const ModLoadingWidget({
    Key key,
  }) : super(key: key);

  @override
  //TODO(MS-1510) stylize this widget
  Widget build(BuildContext context) {
    return new Container(
      color: Colors.white,
      child: new Center(
        child: new Container(
          height: 48.0,
          width: 48.0,
          child: new FuchsiaSpinner(
            color: Colors.blue[700],
          ),
        ),
      ),
    );
  }
}
