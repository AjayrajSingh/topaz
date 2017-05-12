// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

/// Hosts a collection of status icons.
class StatusTrayWidget extends StatelessWidget {
  /// Whether the status tray is displayed on its own or as part of a status
  /// bar.
  final bool isStandalone;

  /// Constructor.
  StatusTrayWidget({this.isStandalone});

  @override
  Widget build(BuildContext context) => new Container(
        decoration: isStandalone
            ? const BoxDecoration(color: const Color(0xccdcdcdc))
            : null,
        child: new Text("3:14"),
      );
}
