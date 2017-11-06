// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dashboard/enums.dart';
import 'package:test/test.dart';

void main() {
  group(BuildStatusEnum, () {
    test(BuildStatusEnum.from, () {
      expect(BuildStatusEnum.from('COMPLETED'), BuildStatusEnum.completed);
      expect(BuildStatusEnum.from('SCHEDULED'), BuildStatusEnum.scheduled);
      expect(BuildStatusEnum.from('STARTED'), BuildStatusEnum.started);
    });
  });

  group(BuildResultEnum, () {
    test(BuildResultEnum.from, () {
      expect(BuildResultEnum.from('SUCCESS'), BuildResultEnum.success);
      expect(BuildResultEnum.from('FAILURE'), BuildResultEnum.failure);
      expect(BuildResultEnum.from('CANCELLED'), BuildResultEnum.cancelled);
    });
  });
}
