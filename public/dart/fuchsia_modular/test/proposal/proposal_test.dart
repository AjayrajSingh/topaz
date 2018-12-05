// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'package:test/test.dart';
import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl;

import 'package:fuchsia_modular/src/proposal/proposal.dart';

void main() {
  test('sets values on display', () {
    final proposal = Proposal(
      id: 'foo',
      headline: 'headline',
      subheadline: 'subheadline',
      details: 'details',
      color: 1,
      annoyance: fidl.AnnoyanceType.blocking,
    );

    final display = proposal.display;
    expect(display.headline, 'headline');
    expect(display.subheadline, 'subheadline');
    expect(display.details, 'details');
    expect(display.color, 1);
    expect(display.annoyance, fidl.AnnoyanceType.blocking);
  });

  test('addModuleAffinity', () {
    final proposal = Proposal(
      id: 'foo',
      headline: 'h',
    )..addModuleAffinity('mod', 'story');

    final affinity = proposal.affinity.first;

    expect(affinity.moduleAffinity.moduleName.first, 'mod');
    expect(affinity.moduleAffinity.storyName, 'story');
  });

  test('addStoryAffinity', () {
    final proposal = Proposal(id: 'foo', headline: 'h')
      ..addStoryAffinity('story');

    final affinity = proposal.affinity.first;
    expect(affinity.storyAffinity.storyName, 'story');
  });
}
