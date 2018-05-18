// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:lib.widgets/widgets.dart';

/// A [TickingDoubleState] that changes its height to 0% of the child's height
/// via [hide] and 100% of the child's height via [show].
abstract class DeviceExtensionState<T extends StatefulWidget>
    extends TickingDoubleState<T> {
  /// Creates the widget fot this device extension.
  Widget createWidget(BuildContext context);

  @override
  void initState() {
    super.initState();
    setValue(0.0, force: true);
    minValue = 0.0;
    maxValue = 100.0;
  }

  /// Hides this widget by shrinking its height to 0% of its parent.
  void hide() {
    setValue(0.0);
  }

  /// Shows this widget by expanding its height to 100% of its parent.
  void show() {
    setValue(100.0);
  }

  /// Hides if showing, shows if hiding.
  void toggle() => active ? hide() : show();

  @override
  Widget build(BuildContext context) {
    /// TODO(apwilson): This is crapping out with new skia!
    return new ClipRect(
      child: new Align(
        alignment: FractionalOffset.topCenter,
        heightFactor: value / 100.0,
        child: new Offstage(
          offstage: value == 0.0,
          child: new RepaintBoundary(
            child: createWidget(context),
          ),
        ),
      ),
    );
  }

  /// Returns true if we're showing any amount of this device extension.
  bool get active => value > minValue;
}
