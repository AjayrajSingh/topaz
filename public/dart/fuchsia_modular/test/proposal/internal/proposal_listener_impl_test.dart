// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'package:test/test.dart';

import 'package:fuchsia_modular/src/proposal/internal/proposal_listener_impl.dart';

void main() {
  test('calls the callback when proposal accepted', () {
    String callbackPid;
    String callbackSid;

    ProposalListenerImpl((pid, sid) {
      callbackPid = pid;
      callbackSid = sid;
    }).onProposalAccepted('proposal', 'story');

    expect(callbackPid, 'proposal');
    expect(callbackSid, 'story');
  });
}
