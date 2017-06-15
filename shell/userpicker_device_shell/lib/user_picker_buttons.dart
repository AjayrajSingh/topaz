// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'circular_button.dart';

import 'user_picker_device_shell_model.dart';

const bool _kShowUserShellToggle = false;

/// Main buttons (Shutdown, New User) for the User Picker
class UserPickerButtons extends StatelessWidget {
  /// Called when the add user button is pressed.
  final VoidCallback onAddUser;

  /// Called when the user shell chooser button is pressed.
  final VoidCallback onUserShellChange;

  /// The asset name of the user shell the user will be logged in with.
  final String userShellAssetName;

  /// Constructor.
  UserPickerButtons({
    this.onAddUser,
    this.onUserShellChange,
    this.userShellAssetName,
  });

  @override
  Widget build(BuildContext context) =>
      new ScopedModelDescendant<UserPickerDeviceShellModel>(
        builder: (
          BuildContext context,
          Widget child,
          UserPickerDeviceShellModel model,
        ) =>
            new Row(
              mainAxisSize: MainAxisSize.min,
              children: _buildRowChildren(model),
            ),
      );

  List<Widget> _buildRowChildren(UserPickerDeviceShellModel model) {
    List<Widget> rowChildren = <Widget>[
      _buildShutdownButton(model),
      new Container(width: 16.0, height: 0.0),
      _buildAddUserButton(model),
    ];
    if (_kShowUserShellToggle) {
      rowChildren.addAll(<Widget>[
        new Container(width: 16.0, height: 0.0),
        _buildUserShellToggleButton(),
      ]);
    }
    return rowChildren;
  }

  Widget _buildShutdownButton(UserPickerDeviceShellModel model) =>
      new CircularButton(
        icon: Icons.power_settings_new,
        onTap: () => model.deviceShellContext?.shutdown(),
      );

  Widget _buildAddUserButton(UserPickerDeviceShellModel model) =>
      new CircularButton(
        icon: Icons.person_add,
        onTap: () => onAddUser?.call(),
      );

  Widget _buildUserShellToggleButton() => new Material(
        type: MaterialType.circle,
        elevation: 2.0,
        color: Colors.grey[200],
        child: new InkWell(
          onTap: () => onUserShellChange?.call(),
          child: new Container(
            padding: const EdgeInsets.all(12.0),
            child: new Image.asset(
              userShellAssetName,
              height: 24.0,
              width: 24.0,
            ),
          ),
        ),
      );
}
