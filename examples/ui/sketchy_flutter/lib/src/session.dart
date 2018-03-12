// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app.dart/app.dart';
import 'package:lib.app.fidl._service_provider/service_provider.fidl.dart';
import 'package:lib.ui.mozart.fidl/commands.fidl.dart';
import 'package:lib.ui.mozart.fidl/mozart.fidl.dart';
import 'package:lib.ui.mozart.fidl/session.fidl.dart';
import 'package:lib.ui.mozart.fidl._presentation_info/presentation_info.fidl.dart';
import 'package:lib.ui.scenic.fidl/ops.fidl.dart';
import 'package:zircon/zircon.dart' as zircon;

export 'package:lib.ui.mozart.fidl._presentation_info/presentation_info.fidl.dart'
    show PresentationInfo;

// ignore_for_file: public_member_api_docs

typedef void SessionPresentCallback(PresentationInfo info);

class Session {
  int _nextResourceId = 1;
  final SessionProxy _session = new SessionProxy();
  List<Command> _ops = <Command>[];

  Session.fromMozart(MozartProxy mozart) {
    mozart.createSession(_session.ctrl.request(), null);
  }

  factory Session.fromServiceProvider(ServiceProvider serviceProvider) {
    final MozartProxy mozart = new MozartProxy();
    connectToService(serviceProvider, mozart.ctrl);
    return new Session.fromMozart(mozart);
  }

  bool get hasEnqueuedOps => _ops.isNotEmpty;

  void enqueue(Op op) {
    _ops.add(new Command.withScenic(op));
  }

  void present(int presentationTime, SessionPresentCallback callback) {
    if (_ops.isNotEmpty) {
      _session.enqueue(_ops);
      _ops = const <Command>[];
    }
    _session.present(
        presentationTime, <zircon.Handle>[], <zircon.Handle>[], callback);
  }

  int nextResourceId() => _nextResourceId++;
}
