// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib_setui_common/action.dart';
import 'package:lib_setui_common/step.dart';

import 'widget_action.dart';
import 'widget_action_client.dart';
import 'widget_action_host.dart';

/// Function prototype for creating a [WidgetActionClient]. Associated with a
/// [Blueprint] to be used by a [WidgetAction] to generate the client on demand.
typedef CreateClient = WidgetActionClient Function(ActionResultSender);

/// A [Blueprint] for a Widget-based [Action].
class WidgetBlueprint extends Blueprint {
  final ActionStateModel model;
  final CreateClient createClient;

  WidgetBlueprint(
      String name, String description, this.model, this.createClient)
      : super(name, description);

  @override
  Action assemble(Step step, ActionResultReceiver receiver) {
    return WidgetAction(step, receiver, this);
  }
}
