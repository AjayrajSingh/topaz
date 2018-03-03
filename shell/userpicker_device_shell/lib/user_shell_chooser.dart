// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

/// Keeps track of the currently chosen user shell.
class UserShellChooser {
  final String _defaultUserShell = 'armadillo_user_shell';
  List<String> _configuredUserShells = <String>[];

  /// Constructor.
  UserShellChooser() {
    File file = new File('/system/data/sysui/user_shell_to_launch');
    file.exists().then((bool exists) {
      if (exists) {
        file.readAsString().then(
          (String userShellLaunchFileContents) {
            _configuredUserShells = userShellLaunchFileContents.split('\n');
          },
        );
      }
    });
  }

  /// Gets the current user shell's app url.
  /// Temporarily use the default user shell if guest for backward compatibility
  String getPrimaryUserShellAppUrl(String user) => _configuredUserShells.isEmpty
      ? _defaultUserShell
      : _configuredUserShells[0];

  /// Gets the secondary user shell's app url.
  String getSecondaryUserShellAppUrl(String user) =>
      _configuredUserShells.length > 1
          ? _configuredUserShells[1]
          : getPrimaryUserShellAppUrl(user);
}
