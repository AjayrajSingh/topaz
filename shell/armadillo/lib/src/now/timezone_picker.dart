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
              new tz.TimezonePicker(
                  currentTimezoneId: contextModel.timezoneId,
                  onTap: (String timezoneId) {
                    contextModel.timezoneId = timezoneId;
                    new Timer(
                      const Duration(milliseconds: 300),
                      () {
                        contextModel.isTimezonePickerShowing = false;
                      },
                    );
                  },
                  onTapOutside: () {
                    contextModel.isTimezonePickerShowing = false;
                  }));
}
