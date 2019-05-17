// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:fuchsia_scenic_flutter/child_view.dart' show ChildView;

import '../models/app_model.dart';
import '../widgets/stories.dart';

/// Builds the main display of this session shell.
class App extends StatelessWidget {
  final AppModel model;

  const App({@required this.model});

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return DefaultTextStyle(
              style: Theme.of(context).primaryTextTheme.body1.copyWith(
                    fontFamily: 'RobotoMono',
                    fontWeight: FontWeight.w400,
                    fontSize: 24.0,
                    color: Colors.white,
                  ),
              child: Container(
                color: model.backgroundColor,
                child: Stack(
                  fit: StackFit.expand,
                  overflow: Overflow.visible,
                  children: <Widget>[
                    // Stories.
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        child: Stories(
                          elevation: 10.0,
                          storyManager: model.storyManager,
                          onChangeStory: (i) {
                            if (i == 0) {
                              model.onMeta();
                            }
                          },
                        ),
                        onLongPress: model.onMeta,
                      ),
                    ),
                    // Ask.
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: model.onCancel,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            model.askVisibility,
                            model.askChildViewConnection
                          ]),
                          builder: (context, child) =>
                              !model.askVisibility.value ||
                                      model.askChildViewConnection.value == null
                                  ? Offstage()
                                  : ChildView(
                                      connection:
                                          model.askChildViewConnection.value,
                                    ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
}
