// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

/// Builds [builder] if [maybe] is true.
class Maybe extends StatelessWidget {
  /// If true, [build] uses [builder] to build.
  final bool maybe;

  /// Builds the [Widget] if [maybe] is true.
  final WidgetBuilder builder;

  /// Place holder [Widget] if [maybe] is false.
  final Widget placeHolder;

  /// Constructor.
  const Maybe({this.maybe, this.builder, this.placeHolder: const Offstage()});

  @override
  Widget build(BuildContext context) => maybe ? builder(context) : placeHolder;
}
