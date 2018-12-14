// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib_setui_common/action.dart';
import 'package:lib_setui_common/step.dart';
import 'package:lib_setui_module/module_action.dart';
import 'package:lib_setui_module/roster_parser.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// A well-formed roster.
const String _testRoster = '''
---
begin:
  verb: start
  handler: com.foo.bar
end:
  verb: finish
  handler: com.foo2.bar
...
''';

/// malformed step due to not being a map.
const String _malformedStepRoster = '''
---
begin: []
...
''';

/// malformed step due to missing attribute.
const String _malformedStep2Roster = '''
---
begin:
  verb: start
...
''';

/// malformed step due to extra attribute.
const String _malformedStep3Roster = '''
---
begin:
  verb: start
  handler: com.foo.bar
  foo: bar
...
''';

/// malformed attr due to incorrectly formatted attribute.
const String _malformedAttributeRoster = '''
---
begin:
  verb: start
  handler: {}
...
''';

/// missing attr due to incorrectly formatted attribute.
const String _missingAttributeRoster = '''
---
begin:
  verb: start
  foo: bar
...
''';

// TODO: Refactor this class to use the new SDK instead of deprecated API
// ignore: deprecated_member_use
class MockDriver extends Mock implements ModuleDriver {}

class MockActionResultReceiver extends Mock implements ActionResultReceiver {}

void main() {
  // Verify parser validation.
  test('test_validate', () {
    expect(RosterParser.validate(null), ParseResult.malformedDoc);
    expect(RosterParser.validate(loadYamlDocument(_testRoster)),
        ParseResult.success);
    expect(RosterParser.validate(loadYamlDocument(_malformedStepRoster)),
        ParseResult.malformedStep);
    expect(RosterParser.validate(loadYamlDocument(_malformedStep2Roster)),
        ParseResult.malformedStep);
    expect(RosterParser.validate(loadYamlDocument(_malformedStep3Roster)),
        ParseResult.malformedStep);
    expect(RosterParser.validate(loadYamlDocument(_malformedAttributeRoster)),
        ParseResult.malformedAttr);
    expect(RosterParser.validate(loadYamlDocument(_missingAttributeRoster)),
        ParseResult.missingAttr);
  });

  // Check roster creation.
  test('test_parse', () {
    final RosterParser parser = new RosterParser(new MockDriver());
    final Roster roster = parser.parse(loadYamlDocument(_testRoster));

    // Ensure the proper number of handlers were generated.
    expect(roster.actionCount, 2);

    final Step step = new Step('test', 'begin');

    ModuleAction action =
        roster.getAction(step, new MockActionResultReceiver());

    expect(action != null, true);
    expect(action.blueprint.handler, 'com.foo.bar');
    expect(action.blueprint.verb, 'start');
  });
}
