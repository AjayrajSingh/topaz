// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO(SCN-617): Fix 'commands_fidl' colliding dart library names.
// ignore_for_file: import_duplicated_library_named

import 'dart:async';

import 'package:lib.app.dart/app_async.dart';
import 'package:fidl_fuchsia_sys/fidl_async.dart';
import 'package:fidl_fuchsia_images/fidl_async.dart';
import 'package:fidl_fuchsia_ui_gfx/fidl_async.dart' as gfx;
import 'package:fidl_fuchsia_ui_scenic/fidl_async.dart' as ui_scenic;
import 'package:zircon/zircon.dart' as zircon;

export 'package:fidl_fuchsia_images/fidl_async.dart' show PresentationInfo;

// ignore_for_file: public_member_api_docs

typedef SessionPresentCallback = void Function(PresentationInfo info);

class Session {
  int _nextResourceId = 1;
  final ui_scenic.SessionProxy _session = new ui_scenic.SessionProxy();
  List<ui_scenic.Command> _commands = <ui_scenic.Command>[];

  Session.fromScenic(ui_scenic.ScenicProxy scenic) {
    scenic.createSession(_session.ctrl.request(), null);
  }

  factory Session.fromServiceProvider(ServiceProvider serviceProvider) {
    final ui_scenic.ScenicProxy scenic = new ui_scenic.ScenicProxy();
    connectToService(serviceProvider, scenic.ctrl);
    return new Session.fromScenic(scenic);
  }

  bool get hasEnqueuedCommands => _commands.isNotEmpty;

  void enqueue(gfx.Command command) {
    _commands.add(new ui_scenic.Command.withGfx(command));
  }

  Future<PresentationInfo> present(int presentationTime) async {
    if (_commands.isNotEmpty) {
      await _session.enqueue(_commands);
      _commands = const <ui_scenic.Command>[];
    }
    return _session
        .present(presentationTime, <zircon.Handle>[], <zircon.Handle>[]);
  }

  int nextResourceId() => _nextResourceId++;
}
