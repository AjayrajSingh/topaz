// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:lib_setui_common/action.dart';
import 'package:lib_setui_common/conductor_builder.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

/// A well-formed syllabus with single use id.
const String _syllabus = '''
---
entry: start
...
---
start:
  action: begin
...
''';

class MockFile extends Mock implements File {}

class MockBlueprint extends Mock implements Blueprint {}

class MockAction extends Mock implements Action {}

void main() {
  // Make sure first action is launched.
  test('test_start', () async {
    final MockFile syllabusFile = MockFile();
    final MockBlueprint blueprint = MockBlueprint();
    final MockAction action = MockAction();

    final Completer<String> completer = Completer<String>()
      ..complete(_syllabus);

    // Load predefined syllabus when
    when(syllabusFile.readAsString()).thenAnswer((_) => completer.future);
    when(blueprint.key).thenReturn('begin');
    when(blueprint.assemble(any, any)).thenReturn(action);

    final ConductorBuilder builder = ConductorBuilder(syllabusFile)
      ..addBlueprint(blueprint);

    (await builder.build()).start();

    // Ensure blueprint is assembled
    verify(blueprint.assemble(any, any));

    // Ensure action is launched
    verify(action.launch());
  });
}
