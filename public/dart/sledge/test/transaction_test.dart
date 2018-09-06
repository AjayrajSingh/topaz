// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'package:lib.app.dart/logging.dart';
import 'package:sledge/sledge.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  setupLogger();

  test('Run a single transaction', () async {
    Sledge sledge = newSledgeForTesting();
    await sledge.runInTransaction(() async {});
  });

  test('Check that multiple empty transactions can be started without awaiting',
      () async {
    Sledge sledge = newSledgeForTesting()
      ..runInTransaction(() async {})   // ignore: unawaited_futures
      ..runInTransaction(() async {});  // ignore: unawaited_futures
    await sledge.runInTransaction(() async {});
  });

  test('Check that modification are queued and ran', () async {
    Sledge sledge = newSledgeForTesting();
    List<int> events = <int>[];
    // ignore: unawaited_futures
    sledge.runInTransaction(() async {
      events.add(0);
    });
    expect(events, equals(<int>[]));
    await sledge.runInTransaction(() async {
      events.add(1);
    });
    expect(events, equals(<int>[0, 1]));
  });
}
