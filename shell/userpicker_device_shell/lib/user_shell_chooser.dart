// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:fuchsia.fidl.presentation/presentation.dart';

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

  /// Constructor.
  UserShellInfo({
    this.name,
    this.screenWidthMm,
    this.screenHeightMm,
    this.displayUsage,
  });
}

/// Keeps track of the currently chosen user shell.
class UserShellChooser {
  final UserShellInfo _defaultUserShell = new UserShellInfo(
    name: 'armadillo_user_shell',
  );
  final List<UserShellInfo> _configuredUserShells = <UserShellInfo>[];
  int _nextUserShellIndex = -1;

  /// Constructor.
  UserShellChooser() {
    File file = new File('/system/data/sysui/user_shell_to_launch');
    file.exists().then((bool exists) {
      if (exists) {
        file.readAsString().then(
          (String userShellLaunchFileContents) {
            try {
              List<Map<String, String>> decodedJson =
                  json.decode(userShellLaunchFileContents);
              for (Map<String, String> userShellInfo in decodedJson) {
                _configuredUserShells.add(
                  new UserShellInfo(
                    name: userShellInfo['name'],
                    screenWidthMm: _parseDouble(userShellInfo['screen_width']),
                    screenHeightMm: _parseDouble(
                      userShellInfo['screen_height'],
                    ),
                    displayUsage: _parseDisplayUsage(
                      userShellInfo['display_usage'],
                    ),
                  ),
                );
              }
            } on Exception {
              // do nothing, we will use default user shell.
            }
          },
        );
      }
    });
  }

  double _parseDouble(String doubleString) {
    return (doubleString?.isEmpty ?? true) ? 0.0 : double.parse(doubleString);
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

  /// Gets the current user shell's app url.
  /// Temporarily use the default user shell if guest for backward compatibility
  UserShellInfo getNextUserShellInfo(String user) {
    if (_configuredUserShells.isNotEmpty) {
      _nextUserShellIndex =
          (_nextUserShellIndex + 1) % _configuredUserShells.length;
      return _configuredUserShells[_nextUserShellIndex];
    }
    return _defaultUserShell;
  }
}
