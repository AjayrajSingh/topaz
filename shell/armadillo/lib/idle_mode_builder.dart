// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';

import 'context_model.dart';
import 'size_model.dart';

/// Builds the idle mode.
class IdleModeBuilder {
  /// Builds the idle mode.
  Widget build(BuildContext context) => new Center(
        child: new ScopedModelDescendant<ContextModel>(
          builder: (
            BuildContext context,
            Widget child,
            ContextModel contextModel,
          ) =>
              new ScopedModelDescendant<SizeModel>(
                builder: (
                  BuildContext context,
                  Widget child,
                  SizeModel sizeModel,
                ) =>
                    new Text(
                      '${contextModel.timeOnly}',
                      style: new TextStyle(
                        fontSize: math.min(
                          sizeModel.screenSize.width / 6.0,
                          sizeModel.screenSize.height / 6.0,
                        ),
                        fontWeight: FontWeight.w200,
                        letterSpacing: 4.0,
                      ),
                    ),
              ),
        ),
      );
}
