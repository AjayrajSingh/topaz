// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular/fidl.dart';

/// Performs the logging out of the user.
class UserLogoutter {
  SessionShellContext _sessionShellContext;

  /// Set from an external source - typically the SessionShell.
  set sessionShellContext(SessionShellContext sessionShellContext) {
    _sessionShellContext = sessionShellContext;
  }

  /// Logs out the user.
  void logout() {
    _sessionShellContext?.logout();
  }
}
