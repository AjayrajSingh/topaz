// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';

import 'widget_action.dart';

/// A Widget that displays the current widget action from an [ActionStateModel].
class WidgetActionHost extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ScopedModelDescendant<ActionStateModel>(
          builder: (
        BuildContext context,
        Widget child,
        ActionStateModel model,
      ) =>
              getWidget(model));

  @visibleForTesting
  Widget getWidget(ActionStateModel model) => model.currentAction != null
      ? model.currentAction.build()
      : Column(children: []);
}

/// A simple model that stores a reference to a current action.
class ActionStateModel extends Model {
  WidgetAction _currentAction;

  /// TODO: move this to a setter once we can instrument properly in tests.
  void setCurrentAction(WidgetAction handler) {
    _currentAction = handler;
    notifyListeners();
  }

  WidgetAction get currentAction => _currentAction;
}
