// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_setui/fidl.dart';
import 'package:lib_setui_settings_common/setting_adapter.dart';
import 'package:lib_setui_settings_common/setting_controller.dart';

/// A controller class for interacting with time zones.
class TimeZoneController extends SettingController<TimeZoneInfo> {
  TimeZoneController(SettingAdapter adapter) : super(adapter);

  /// Sets the system timezone to the specified zone.
  void setCurrentTimeZone(TimeZone timeZone) {
    mutate(
        Mutation.withTimeZoneMutationValue(TimeZoneMutation(
            value:
                TimeZoneInfo(available: state.available, current: timeZone))),
        null /* handles */);
  }
}
