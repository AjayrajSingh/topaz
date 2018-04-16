// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:timezone/timezone_picker.dart' as tz;

import 'context_model.dart';

/// Allows the selection of timezone.
class TimezonePicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) => new ScopedModelDescendant<ContextModel>(
          builder: (
        BuildContext context,
        Widget child,
        ContextModel contextModel,
      ) =>
              new Stack(children: <Widget>[
                new Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (PointerDownEvent pointerDownEvent) {
                    contextModel.isTimezonePickerShowing = false;
                  },
                ),
                new Center(
                    child: new Material(
                        color: Colors.white,
                        borderRadius: new BorderRadius.circular(8.0),
                        elevation: 899.0,
                        child: new FractionallySizedBox(
                            heightFactor: 0.7,
                            widthFactor: 0.7,
                            child: new tz.TimezonePicker(
                                currentTimezoneId: contextModel.timezoneId,
                                onTap: (String timezoneId) {
                                  contextModel.timezoneId = timezoneId;
                                  new Timer(
                                    const Duration(milliseconds: 300),
                                    () {
                                      contextModel.isTimezonePickerShowing =
                                          false;
                                    },
                                  );
                                }))))
              ]));
}
