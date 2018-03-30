// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO(SCN-617): Fix 'commands_fidl' colliding dart library names.
// ignore_for_file: import_duplicated_library_named

import 'package:lib.app.dart/app.dart';
import 'package:fuchsia.fidl.component/component.dart';
import 'package:fuchsia.fidl.images/images.dart';
import 'package:fuchsia.fidl.gfx/gfx.dart' as gfx;
import 'package:fuchsia.fidl.ui/ui.dart' as ui;
import 'package:zircon/zircon.dart' as zircon;

export 'package:fuchsia.fidl.images/images.dart' show PresentationInfo;

// ignore_for_file: public_member_api_docs

typedef void SessionPresentCallback(PresentationInfo info);

class Session {
  int _nextResourceId = 1;
  final ui.SessionProxy _session = new ui.SessionProxy();
  List<ui.Command> _commands = <ui.Command>[];

  Session.fromScenic(ui.ScenicProxy scenic) {
    scenic.createSession(_session.ctrl.request(), null);
  }

  factory Session.fromServiceProvider(ServiceProvider serviceProvider) {
    final ui.ScenicProxy scenic = new ui.ScenicProxy();
    connectToService(serviceProvider, scenic.ctrl);
    return new Session.fromScenic(scenic);
  }

  bool get hasEnqueuedCommands => _commands.isNotEmpty;

  void enqueue(gfx.Command command) {
    _commands.add(new ui.Command.withGfx(command));
  }

  void present(int presentationTime, SessionPresentCallback callback) {
    if (_commands.isNotEmpty) {
      _session.enqueue(_commands);
      _commands = const <ui.Command>[];
    }
    _session.present(
        presentationTime, <zircon.Handle>[], <zircon.Handle>[], callback);
  }

  int nextResourceId() => _nextResourceId++;
}
