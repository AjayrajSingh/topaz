// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:yaml/yaml.dart';

import 'action.dart';
import 'conductor.dart';
import 'syllabus.dart';
import 'syllabus_parser.dart';

/// A builder for assembling a [Conductor]. Abstracts away details surrounding
/// the [Roster] and [Syllabus].
class ConductorBuilder {
  final Roster _roster = Roster();
  final File _syllabusFile;

  /// Constructs a builder with a [Syllabus] at the specified [File].
  ConductorBuilder(this._syllabusFile);

  /// Adds a [Blueprint] to be used by the [Conductor].
  void addBlueprint(Blueprint blueprint) => _roster.add(blueprint);

  /// Builds the [Conductor].
  Future<Conductor> build() {
    Completer<Conductor> completer = Completer<Conductor>();

    _syllabusFile.readAsString().then((String config) {
      final Syllabus syllabus = SyllabusParser.parse(loadYamlDocuments(config));
      completer.complete(Conductor(syllabus, _roster));
    });

    return completer.future;
  }
}
