// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app.dart/app_async.dart';
import 'package:lib.app.dart/logging.dart';

import 'src/agent.dart';

void main(List<String> args) {
  setupLoggerAsync(name: 'game_tracker_agent');

  // Create agent and advertise it so it can be accessed from other components.
  new GameTrackerAgent(
    startupContext: new StartupContext.fromStartupInfo(),
  ).advertise();
}
