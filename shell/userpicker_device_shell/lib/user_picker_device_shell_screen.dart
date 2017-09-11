// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:lib.app.fidl/application_launcher.fidl.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/application.dart';
import 'package:meta/meta.dart';

import 'clock.dart';
import 'user_picker_device_shell_model.dart';
import 'user_picker_screen.dart';

/// The root widget which displays all the other windows of this app.
class UserPickerDeviceShellScreen extends StatelessWidget {
  /// Launcher to launch the kernel panic module if needed.
  final ApplicationLauncher launcher;

  /// Constructor.
  UserPickerDeviceShellScreen({
    Key key,
    @required this.launcher,
  })
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return new ScopedModelDescendant<UserPickerDeviceShellModel>(
      builder: (
        BuildContext context,
        Widget child,
        UserPickerDeviceShellModel model,
      ) {
        List<Widget> stackChildren = <Widget>[
          new UserPickerScreen(),
        ];

        // Add System Clock
        stackChildren.add(new Align(
          alignment: FractionalOffset.center,
          child: new Offstage(
            offstage: !model.showingClock,
            child: new Clock(),
          ),
        ));

        // Add kernel panic screen
        if (model.showingKernelPanic) {
          stackChildren.add(
            /// TODO(apwilson): Remove gesture detector and make kernel_panic
            /// hittestable when DNO-86 is fixed.
            new GestureDetector(
              onTap: model.hideKernelPanic,
              child: new ApplicationWidget(
                url: 'kernel_panic',
                launcher: launcher,
                onDone: model.hideKernelPanic,
                hitTestable: false,
              ),
            ),
          );
        }

        if (model.childViewConnection != null) {
          stackChildren.add(
            new ChildView(connection: model.childViewConnection),
          );
        }

        return new Stack(fit: StackFit.expand, children: stackChildren);
      },
    );
  }
}
