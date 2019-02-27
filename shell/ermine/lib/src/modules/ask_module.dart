// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:fuchsia_services/services.dart' show StartupContext;
import 'package:fuchsia_logger/logger.dart';

import 'ask_model.dart';
import 'ask_suggestion_list.dart';
import 'ask_text_field.dart';

void main() {
  setupLogger(name: 'ermine_ask_module');

  AskModel model = AskModel(
    startupContext: StartupContext.fromStartupInfo(),
  )..advertise();

  runApp(AskModule(model: model));
}

class AskModule extends StatelessWidget {
  final AskModel model;

  const AskModule({this.model});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultTextStyle(
        style: Theme.of(context).primaryTextTheme.body1.copyWith(
              fontFamily: 'RobotoMono',
              fontWeight: FontWeight.w400,
              fontSize: 24.0,
              color: Colors.white,
            ),
        child: Builder(
          builder: (context) => GestureDetector(
                behavior: HitTestBehavior.translucent,
                onLongPress: model.show,
                onTap: model.hide,
                child: AnimatedBuilder(
                  animation: model.visibility,
                  child: Column(
                    children: <Widget>[
                      Expanded(
                        child: Offstage(),
                      ),
                      AskTextField(
                        model: model,
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 5),
                      ),
                      Expanded(
                        child: AskSuggestionList(
                          model: model,
                        ),
                      ),
                    ],
                  ),
                  builder: (context, child) {
                    if (model.isVisible) {
                      model.focus(context);
                      return child;
                    } else {
                      model.unfocus();
                      return Offstage(child: child);
                    }
                  },
                ),
              ),
        ),
      ),
    );
  }
}
