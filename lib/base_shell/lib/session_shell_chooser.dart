// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fidl_fuchsia_ui_policy/fidl.dart';

/// Keeps track of the currently chosen session shell.
class SessionShellChooser {
  final List<SessionShellInfo> _configuredSessionShells = <SessionShellInfo>[];
  int _sessionShellIndex = 0;

  /// Gets the session shell info of the current shell.
  SessionShellInfo get currentSessionShell {
    if (_configuredSessionShells.isNotEmpty) {
      return _configuredSessionShells[_sessionShellIndex];
    }
    return null;
  }

  /// Load available shells from the filesystem.
  Future<void> init() async {
    try {
      File file = new File('/system/data/sysui/base_shell_config.json');
      if (file.existsSync()) {
        dynamic decodedJson = json.decode(await file.readAsString());

        _configuredSessionShells.addAll(
          decodedJson.map<SessionShellInfo>(
            (sessionShellInfo) => new SessionShellInfo(
                  name: sessionShellInfo['name'],
                  screenWidthMm: _parseDouble(sessionShellInfo['screen_width']),
                  screenHeightMm: _parseDouble(
                    sessionShellInfo['screen_height'],
                  ),
                  displayUsage: _parseDisplayUsage(
                    sessionShellInfo['display_usage'],
                  ),
                  autoLogin: (sessionShellInfo['auto_login'] ?? 'false')
                          .toLowerCase() ==
                      'true',
                ),
          ),
        );
      }

      /// If there is an exception just use the default shell
    } on Exception catch (_) {}
  }

  /// Switch to next shell.  Returns false if no session shells are configured or
  /// there's only one session shell.
  bool swapSessionShells() {
    if (_configuredSessionShells.length <= 1) {
      return false;
    }
    _sessionShellIndex =
        (_sessionShellIndex + 1) % _configuredSessionShells.length;
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

/// Gives information about screen size and device usage a session shell is expected
/// to run with.
class SessionShellInfo {
  /// The name of the session shell's package.
  final String name;

  /// The width of the screen the session shell expects to run with.  If null, the
  /// native screen width is expected.
  final double screenWidthMm;

  /// The height of the screen the session shell expects to run with.  If null, the
  /// native screen height is expected.
  final double screenHeightMm;

  /// The display usage the session shell expects to run with.  If null, the
  /// native display usage is expected.
  final DisplayUsage displayUsage;

  /// True if this session shell supports autologging in.
  final bool autoLogin;

  /// Constructor.
  SessionShellInfo({
    this.name,
    this.screenWidthMm,
    this.screenHeightMm,
    this.displayUsage,
    this.autoLogin,
  });
}
