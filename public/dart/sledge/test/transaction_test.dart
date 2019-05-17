// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'package:fuchsia_logger/logger.dart';
import 'package:sledge/sledge.dart';
import 'package:test/test.dart';

import 'helpers.dart';

class _RollbackException implements Exception {}

void main() {
  setupLogger();

  test('Run a single transaction', () async {
    Sledge sledge = newSledgeForTesting();
    await sledge.runInTransaction(() async {});
  });

  test('Check that multiple empty transactions can be started without awaiting',
      () async {
    Sledge sledge = newSledgeForTesting()
      // ignore: unawaited_futures
      ..runInTransaction(() async {})
      // ignore: unawaited_futures
      ..runInTransaction(() async {});
    await sledge.runInTransaction(() async {});
  });

  test('Check that modification are queued and ran', () async {
    Sledge sledge = newSledgeForTesting();
    List<int> events = <int>[];
    // ignore: unawaited_futures
    sledge.runInTransaction(() async {
      await Future(() => events.add(0));
    });
    expect(events, equals(<int>[]));
    await sledge.runInTransaction(() async {
      events.add(1);
    });
    expect(events, equals(<int>[0, 1]));
  });

  test('Check that abortAndRollback works', () async {
    Map<String, BaseType> schemaDescription = <String, BaseType>{
      'written': Boolean()
    };
    Schema schema = Schema(schemaDescription);

    Sledge sledge = newSledgeForTesting();
    Document doc;
    await sledge.runInTransaction(() async {
      doc = await sledge.getDocument(DocumentId(schema));
      doc['written'].value = false;
    });
    expect(doc['written'].value, equals(false));

    bool modificationSucceeded = await sledge.runInTransaction(() async {
      doc['written'].value = true;
      sledge.abortAndRollback();
    });
    expect(modificationSucceeded, equals(false));
    expect(doc['written'].value, equals(false));
  });

  test('Check that exceptions rollback transactions', () async {
    Map<String, BaseType> schemaDescription = <String, BaseType>{
      'written': Boolean()
    };
    Schema schema = Schema(schemaDescription);

    Sledge sledge = newSledgeForTesting();
    Document doc;
    await sledge.runInTransaction(() async {
      doc = await sledge.getDocument(DocumentId(schema));
      doc['written'].value = false;
    });
    expect(doc['written'].value, equals(false));

    try {
      await sledge.runInTransaction(() async {
        doc['written'].value = true;
        throw _RollbackException();
      });
      // unreachable
      expect(false, equals(true));
    } on _RollbackException {
      //exception intended
    }
    expect(doc['written'].value, equals(false));
  });

  test('Check that exceptions remove transactions from the queue', () async {
    Sledge sledge = newSledgeForTesting();
    try {
      await sledge.runInTransaction(() async {
        throw _RollbackException();
      });
    } on _RollbackException {
      //exception intended
    }

    await sledge.runInTransaction(() async {});
  });
}
