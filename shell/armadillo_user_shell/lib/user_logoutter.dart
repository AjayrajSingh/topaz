// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia.fidl.modular/modular.dart';

/// Performs the logging out of the user.
class UserLogoutter {
  UserShellContext _userShellContext;

  /// Set from an external source - typically the UserShell.
  set userShellContext(UserShellContext userShellContext) {
    _userShellContext = userShellContext;
  }

  /// Logs out the user.
  void logout() {
    _userShellContext?.logout();
  }
}
