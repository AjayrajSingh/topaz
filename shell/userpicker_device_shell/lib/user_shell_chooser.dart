// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

/// Keeps track of the currently chosen user shell.
class UserShellChooser {
  String _userShellAppUrl = 'armadillo_user_shell';

  /// Constructor.
  UserShellChooser() {
    File file = new File('/system/data/sysui/user_shell_to_launch');
    file.exists().then((bool exists) {
      if (exists) {
        file.readAsString().then(
          (String userShellAppUrl) {
            _userShellAppUrl = userShellAppUrl;
          },
        );
      }
    });
  }

  /// Gets the current user shell's app url.
  String get appUrl => _userShellAppUrl;
}
