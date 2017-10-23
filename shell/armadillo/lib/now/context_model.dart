// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';
import 'package:sysui_widgets/time_stringer.dart';

export 'package:lib.widgets/model.dart'
    show ScopedModel, Model, ScopedModelDescendant;

const String _kBackgroundImage = 'packages/armadillo/res/Background.jpg';

/// The Device's mode.
enum DeviceMode {
  /// Normal mode.
  normal,

  /// Edge to edge mode.
  edgeToEdge,
}

/// Provides assets and text based on context.
abstract class ContextModel extends Model {
  final TimeStringer _timeStringer = new TimeStringer();

  /// The current background image to use.
  ImageProvider get backgroundImageProvider => const AssetImage(
        _kBackgroundImage,
      );

  /// The current wifi network.
  String get wifiNetwork => 'GoogleGuest';

  /// The current contextual location.
  String get contextualLocation => 'in San Francisco';

  /// The current time.
  String get timeOnly => _timeStringer.timeOnly;

  /// The current date.
  String get dateOnly => _timeStringer.dateOnly;

  /// The current meridiem
  String get meridiem => _timeStringer.meridiem;

  /// The user's name.
  String get userName;

  /// The user's image url.
  String get userImageUrl;

  /// The timestamp of the build.
  DateTime get buildTimestamp;

  /// The mode of the device.
  DeviceMode get deviceMode;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (listenerCount == 1) {
      _timeStringer.addListener(notifyListeners);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (listenerCount == 0) {
      _timeStringer.removeListener(notifyListeners);
    }
  }
}
