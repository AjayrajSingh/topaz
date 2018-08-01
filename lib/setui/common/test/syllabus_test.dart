// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib_setiu_common/step.dart';
import 'package:lib_setiu_common/syllabus.dart';
import 'package:test/test.dart';

void main() {
  // Makes sure retrieveStep retrieves the [Step] by the given name or returns
  // null if it doesn't exist.
  test('test_step_retrieval', () {
    final Step child3 = new Step('step3', 'action3');
    final Step child2 = new Step('step2', 'action2')
      ..addResult('result', child3);
    final Step child1 = new Step('step1', 'action1')
      ..addResult('result', child2);

    final Syllabus syllabus = new Syllabus(child1, null /*singleUseId*/);

    expect(syllabus.retrieveStep('step3'), child3);
    expect(syllabus.retrieveStep('unknownStep'), null);
  });
}
