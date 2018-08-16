// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib_setui_common/syllabus.dart';
import 'package:lib_setui_common/syllabus_parser.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// A well-formed syllabus.
const String _testSyllabus = '''
---
entry: start
...
---
start:
  action: begin
  default_transition: connectivity
  results:  {signin: login}
connectivity:
  action: connect
  results: {repeat: connectivity, finish: end}
login:
  action: authenticate
  default_transition: end
end:
  action: finish
...
''';

/// A syllabus with a default_transition.
const String _defaultTransitionSyllabus = '''
---
entry: start
...
---
start:
  action: begin
  default_transition: connectivity
connectivity:
  action: connect
...
''';

/// A well-formed syllabus with single use id.
const String _singleUseIdSyllabus = '''
---
entry: start
single_use_id: com.test.syllabus.id
...
---
start:
  action: begin
...
''';

/// The single use id should be a [String].
const String _malformedSingleUseIdSyllabus = '''
---
entry: start
single_use_id: [one, two, three]
...
---
start:
  action: begin
...
''';

/// The syllabus is missing step definitions.
const String _wrongLengthSyllabus = '''
---
entry: start
...
''';

/// A result step is referenced without being defined.
const String _missingResultStepSyllabus = '''
---
entry: start
...
---
start:
  action: begin
  default_transition: connectivity
  results:  {signin: login}
connectivity:
  action: connect
...
''';

/// The entry points to a non-existent step.
const String _undefinedEntrySyllabus = '''
---
entry: nonexist
...
---
start:
  action: begin
...
''';

/// The results field should be a map.
const String _malformedResultSyllabus = '''
---
entry: start
...
---
start:
  action: begin
  results: nothing
...
''';

/// The results field key is misspelled.
const String _malformedStepSyllabus = '''
---
entry: start
...
---
start:
  action: begin
  res: nothing
...
''';

/// Extra entry under the metadata.
const String _malformedMetaSyllabus = '''
---
entry: start
last: foo
...
---
start:
  action: begin
...
''';

/// The resulting step is undefined.
const String _undefinedResultSyllabus = '''
---
entry: start
...
---
start:
  action: begin
  results: {foo: bar}
...
''';

/// The next step is undefined.
const String _undefinedNextSyllabus = '''
---
entry: start
...
---
start:
  action: begin
  default_transition: foo
...
''';

/// Unreachable step.
const String _unreachableStepSyllabus = '''
---
entry: start
...
---
start:
  action: begin
end:
  action: finish
...
''';

/// Unreachable step.
const String _emptySyllabus = '''
---
...
''';

void main() {
  // Exercises SyllabusParser's validate method, which ensures syllabus
  // files are well-formed before consuming.
  test('test_validation', () {
    expect(SyllabusParser.validate(loadYamlDocuments(_testSyllabus)),
        ParseResult.success);
    expect(SyllabusParser.validate(loadYamlDocuments(_singleUseIdSyllabus)),
        ParseResult.success);
    expect(
        SyllabusParser
            .validate(loadYamlDocuments(_malformedSingleUseIdSyllabus)),
        ParseResult.malformedSingleUseId);
    expect(
        SyllabusParser.validate(loadYamlDocuments(_missingResultStepSyllabus)),
        ParseResult.undefinedResultStep);
    expect(SyllabusParser.validate(null), ParseResult.wronglength);
    expect(SyllabusParser.validate(loadYamlDocuments(_emptySyllabus)),
        ParseResult.wronglength);
    expect(SyllabusParser.validate(loadYamlDocuments(_wrongLengthSyllabus)),
        ParseResult.wronglength);
    expect(SyllabusParser.validate(loadYamlDocuments(_undefinedEntrySyllabus)),
        ParseResult.entryNotDefined);
    expect(SyllabusParser.validate(loadYamlDocuments(_malformedResultSyllabus)),
        ParseResult.malformedResults);
    expect(SyllabusParser.validate(loadYamlDocuments(_malformedStepSyllabus)),
        ParseResult.malformedStep);
    expect(SyllabusParser.validate(loadYamlDocuments(_malformedMetaSyllabus)),
        ParseResult.malformedMetaData);
    expect(SyllabusParser.validate(loadYamlDocuments(_undefinedResultSyllabus)),
        ParseResult.undefinedResultStep);
    expect(SyllabusParser.validate(loadYamlDocuments(_undefinedNextSyllabus)),
        ParseResult.undefinedDefaultTransition);
    expect(SyllabusParser.validate(loadYamlDocuments(_unreachableStepSyllabus)),
        ParseResult.unreachableStep);
  });

  // Verifies the syllabus object generated is consistent with the input.
  test('test_syllabus_creation', () {
    final Syllabus syllabus =
        SyllabusParser.parse(loadYamlDocuments(_singleUseIdSyllabus));

    expect(syllabus.retrieveStep('start').action, 'begin');
    expect(syllabus.singleUseId, 'com.test.syllabus.id');
    expect(syllabus.entry.key, 'start');
  });

  // Ensures default transition is set properly
  test('test_default_transition', () {
    final Syllabus syllabus =
        SyllabusParser.parse(loadYamlDocuments(_defaultTransitionSyllabus));
    expect(syllabus.entry.getNext() != null, true);
  });
}
