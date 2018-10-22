// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fidl_fuchsia_ui_policy/fidl.dart';

/// Keeps track of the currently chosen user shell.
class UserShellChooser {
  final List<UserShellInfo> _configuredUserShells = <UserShellInfo>[];
  int _userShellIndex = 0;

  /// Gets the user shell info of the current shell.
  UserShellInfo get currentUserShell {
    if (_configuredUserShells.isNotEmpty) {
      return _configuredUserShells[_userShellIndex];
    }
    return null;
  }

  /// Load available shells from the filesystem.
  Future<void> init() async {
    try {
      File file = new File('/system/data/sysui/base_shell_config.json');
      if (file.existsSync()) {
        dynamic decodedJson = json.decode(await file.readAsString());

        _configuredUserShells.addAll(
          decodedJson.map<UserShellInfo>(
            (userShellInfo) => new UserShellInfo(
                  name: userShellInfo['name'],
                  screenWidthMm: _parseDouble(userShellInfo['screen_width']),
                  screenHeightMm: _parseDouble(
                    userShellInfo['screen_height'],
                  ),
                  displayUsage: _parseDisplayUsage(
                    userShellInfo['display_usage'],
                  ),
                  autoLogin:
                      (userShellInfo['auto_login'] ?? 'false').toLowerCase() ==
                          'true',
                ),
          ),
        );
      }

      /// If there is an exception just use the default shell
    } on Exception catch (_) {}
  }

  /// Switch to next shell.  Returns false if no user shells are configured or
  /// there's only one user shell.
  bool swapUserShells() {
    if (_configuredUserShells.length <= 1) {
      return false;
    }
    _userShellIndex = (_userShellIndex + 1) % _configuredUserShells.length;
    return true;
  }

  DisplayUsage _parseDisplayUsage(String displayUsage) {
    switch (displayUsage) {
      case 'handheld':
        return DisplayUsage.kHandheld;
      case 'close':
        return DisplayUsage.kClose;
      case 'near':
        return DisplayUsage.kNear;
      case 'midrange':
        return DisplayUsage.kMidrange;
      case 'far':
        return DisplayUsage.kFar;
      default:
        return DisplayUsage.kUnknown;
    }
  }

  double _parseDouble(String doubleString) {
    return (doubleString?.isEmpty ?? true) ? 0.0 : double.parse(doubleString);
  }
}

/// Gives information about screen size and device usage a user shell is expected
/// to run with.
class UserShellInfo {
  /// The name of the user shell's package.
  final String name;

  /// The width of the screen the user shell expects to run with.  If null, the
  /// native screen width is expected.
  final double screenWidthMm;

  /// The height of the screen the user shell expects to run with.  If null, the
  /// native screen height is expected.
  final double screenHeightMm;

  /// The display usage the user shell expects to run with.  If null, the
  /// native display usage is expected.
  final DisplayUsage displayUsage;

  /// True if this user shell supports autologging in.
  final bool autoLogin;

  /// Constructor.
  UserShellInfo({
    this.name,
    this.screenWidthMm,
    this.screenHeightMm,
    this.displayUsage,
    this.autoLogin,
  });
}
