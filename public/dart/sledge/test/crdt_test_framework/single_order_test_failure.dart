// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import 'evaluation_order.dart';
import 'node.dart';

class SingleOrderTestFailure extends TestFailure {
  final EvaluationOrder order;
  final Node failedOn;

  SingleOrderTestFailure(TestFailure failure, this.order, this.failedOn)
      : super(failure.message);

  @override
  String get message {
    return 'SingleOrderTestFailure.\n'
        'Parent TestFailure:\n'
        '-----------------\n'
        '${super.message}'
        '-----------------\n'
        'Failure on node $failedOn\n'
        'The same evaluation order might be reproduced by:\n'
        '.testFixedOrder($order)\n'
        '-----------------\n';
  }
}
