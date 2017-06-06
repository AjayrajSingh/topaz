// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';

import '../modular/module_model.dart';

/// The screen to video player.
class Screen extends StatelessWidget {
  /// The screen for video player
  Screen({
    Key key,
  })
      : super(key: key);

  Widget _buildScreen(VideoModuleModel model) {
    return new Expanded(
      child: new Center(
        child: new GestureDetector(
          onTap: null,
          child: model.videoViewConnection != null
              ? new ChildView(connection: model.videoViewConnection)
              : new Container(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return new ScopedModelDescendant<VideoModuleModel>(
      builder: (
        BuildContext context,
        Widget child,
        VideoModuleModel model,
      ) {
        // TODO(maryxia) SO-480 make this conditional via onTap
        model.brieflyShowControlOverlay();
        return _buildScreen(model);
      },
    );
  }
}
