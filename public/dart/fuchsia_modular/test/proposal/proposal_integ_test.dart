// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:test/test.dart';
import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl;
import 'package:fidl_fuchsia_modular/fidl_test.dart' as fidl_test;

import 'package:fuchsia_modular/src/proposal/proposal.dart';

void main() {
  test('calls the set onAccept function', () async {
    final completer = Completer();
    final proposal = Proposal(
        id: 'foo',
        headline: 'headline',
        onProposalAccepted: (i, s) {
          completer.complete();
        });

    final publisher = _MockProposalPublisherImpl();
    await Future.wait([
      publisher.propose(proposal),
      completer.future,
    ]);
  }, timeout: Timeout(Duration(milliseconds: 100)));
}

class _MockProposalPublisherImpl extends fidl_test.ProposalPublisher$TestBase {
  @override
  Future<void> propose(fidl.Proposal proposal) async {
    final listenerHandle = proposal.listener;
    if (listenerHandle == null) {
      return;
    }

    final listenerProxy = fidl.ProposalListenerProxy();
    listenerProxy.ctrl.bind(listenerHandle);

    await listenerProxy.onProposalAccepted(proposal.id, 'foo-story-id');
  }
}
