// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO(SCN-617): Fix 'commands_fidl' colliding dart library names.
// ignore_for_file: import_duplicated_library_named

import 'package:lib.app.dart/app.dart';
import 'package:lib.app.fidl._service_provider/service_provider.fidl.dart';
import 'package:lib.ui.scenic.fidl/commands.fidl.dart' as scenic;
import 'package:lib.ui.scenic.fidl/scenic.fidl.dart';
import 'package:lib.ui.scenic.fidl/session.fidl.dart';
import 'package:lib.ui.scenic.fidl._presentation_info/presentation_info.fidl.dart';
import 'package:lib.ui.gfx.fidl/commands.fidl.dart' as ui_gfx;
import 'package:zircon/zircon.dart' as zircon;

export 'package:lib.ui.scenic.fidl._presentation_info/presentation_info.fidl.dart'
    show PresentationInfo;

// ignore_for_file: public_member_api_docs

typedef void SessionPresentCallback(PresentationInfo info);

class Session {
  int _nextResourceId = 1;
  final SessionProxy _session = new SessionProxy();
  List<scenic.Command> _commands = <scenic.Command>[];

  Session.fromScenic(ScenicProxy scenic) {
    scenic.createSession(_session.ctrl.request(), null);
  }

  factory Session.fromServiceProvider(ServiceProvider serviceProvider) {
    final ScenicProxy scenic = new ScenicProxy();
    connectToService(serviceProvider, scenic.ctrl);
    return new Session.fromScenic(scenic);
  }

  bool get hasEnqueuedCommands => _commands.isNotEmpty;

  void enqueue(ui_gfx.Command command) {
    _commands.add(new scenic.Command.withGfx(command));
  }

  void present(int presentationTime, SessionPresentCallback callback) {
    if (_commands.isNotEmpty) {
      _session.enqueue(_commands);
      _commands = const <scenic.Command>[];
    }
    _session.present(
        presentationTime, <zircon.Handle>[], <zircon.Handle>[], callback);
  }

  int nextResourceId() => _nextResourceId++;
}
