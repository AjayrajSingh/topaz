// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia_logger/logger.dart';
import 'package:lib_setui_common/step.dart';
import 'package:lib_setui_common/syllabus.dart';
import 'package:meta/meta.dart';
import 'package:yaml/yaml.dart';

/// Results that can be returned during validation.
enum ParseResult {
  success,
  wronglength,
  missingEntry,
  malformedMetaData,
  entryNotDefined,
  malformedStep,
  missingAction,
  malformedDefaultTransition,
  undefinedDefaultTransition,
  malformedResults,
  undefinedResultStep,
  malformedSingleUseId,
  unreachableStep,
}

/// The parser responsible for producing a [Syllabus] from a series of YAML
/// configuration files.
class SyllabusParser {
  static const String _keyEntry = 'entry';
  static const String _keySingleUseId = 'single_use_id';
  static const String _keyAction = 'action';
  static const String _keyResults = 'results';
  static const String _keyDefaultTransition = 'default_transition';

  /// Parses the provided configuration [docs] to generate a [Syllabus]. If
  /// there is an issue with the configuration, null will be returned.
  static Syllabus parse(List<YamlDocument> docs) {
    final ParseResult result = validate(docs);
    if (result != ParseResult.success) {
      log.severe('Error parsing syllabus: $result');
      return null;
    }

    final Map<String, Step> steps = {};

    // First pass: create steps.
    docs[1].contents.value.forEach((key, value) {
      final String action = value[_keyAction];
      steps[key] = Step(key, action);
    });

    // Second pass: link up nodes.
    docs[1].contents.value.forEach((key, stepAttr) {
      final Step step = steps[key];
      if (stepAttr.keys.contains(_keyResults)) {
        stepAttr[_keyResults].value.forEach((key, value) {
          if (key is String && value is String) {
            step.addResult(key, value);
          }
        });
      }

      if (stepAttr.keys.contains(_keyDefaultTransition)) {
        step.defaultTransition = stepAttr[_keyDefaultTransition];
      }
    });

    final YamlMap metaData = docs[0].contents.value;

    return Syllabus(steps.values.toList(), steps[metaData[_keyEntry]],
        metaData[_keySingleUseId]);
  }

  /// Ensures that the specified docs are of the correct format. If successful,
  /// [ParseResult.success] will be returned.
  @visibleForTesting
  static ParseResult validate(List<YamlDocument> docs) {
    // Make sure there are two docs.
    if (docs == null || docs.length != 2) {
      return ParseResult.wronglength;
    }

    // Make sure the documents are both maps.
    if (!(docs[0].contents.value is YamlMap &&
        docs[1].contents.value is YamlMap)) {
      return ParseResult.malformedMetaData;
    }

    final YamlMap metaData = docs[0].contents.value;

    // Check defined meta-data keys.
    if (!_onlyHasKeys(metaData, [_keyEntry, _keySingleUseId])) {
      return ParseResult.malformedMetaData;
    }

    // Ensure entry exists.
    if (metaData[_keyEntry] == null) {
      return ParseResult.missingEntry;
    }

    // Make sure single use id is well-formed.
    if (metaData[_keySingleUseId] != null &&
        !(metaData[_keySingleUseId] is String)) {
      return ParseResult.malformedSingleUseId;
    }

    final String entry = metaData[_keyEntry];

    final YamlMap steps = docs[1].contents.value;

    final Set<String> stepNames = steps.keys.toSet().cast<String>();

    final Map<String, Set<String>> stepResults = {};

    // Validate each individual step.
    for (String stepName in stepNames) {
      final Set<String> encounteredSteps = <String>{};
      final ParseResult stepResult =
          _validateStep(steps[stepName], stepNames, encounteredSteps);

      if (stepResult != ParseResult.success) {
        return stepResult;
      }

      stepResults[stepName] = encounteredSteps;
    }

    // Make sure entry is defined.
    if (!stepNames.contains(entry)) {
      return ParseResult.entryNotDefined;
    }

    // Traverse to find reachable nodes
    final Set<String> reachableNodes = <String>{};
    final List<String> pendingVisits = [entry];

    while (pendingVisits.isNotEmpty) {
      final String targetStep = pendingVisits.removeAt(0);

      if (reachableNodes.contains(targetStep)) {
        continue;
      }

      reachableNodes.add(targetStep);

      pendingVisits.addAll(stepResults[targetStep]);
    }

    for (String stepName in stepNames) {
      if (!reachableNodes.contains(stepName)) {
        return ParseResult.unreachableStep;
      }
    }

    return ParseResult.success;
  }

  /// Validate the syntatic correctness of the step definition.
  /// [ParseResult.success] will be returned. This function also returns the
  /// set of immediately reachable steps in [encounteredSteps].
  static ParseResult _validateStep(
      YamlNode stepNode, Set<String> stepNames, Set<String> encounteredSteps) {
    // The step should be defined as a map.
    if (!(stepNode is YamlMap)) {
      return ParseResult.malformedStep;
    }

    final YamlMap step = stepNode;

    // Check only known keys are present.
    if (!_onlyHasKeys(step, [_keyAction, _keyDefaultTransition, _keyResults])) {
      return ParseResult.malformedStep;
    }

    // Steps must define an action.
    if (!step.keys.contains(_keyAction)) {
      return ParseResult.missingAction;
    }

    // If a default transition is present, make sure it's a String and also
    // points to a defined step.
    if (step.keys.contains(_keyDefaultTransition)) {
      if (!(step[_keyDefaultTransition] is String)) {
        return ParseResult.malformedDefaultTransition;
      }

      final String defaultTransition = step[_keyDefaultTransition];
      if (!stepNames.contains(defaultTransition)) {
        return ParseResult.undefinedDefaultTransition;
      }

      encounteredSteps.add(defaultTransition);
    }

    // Make sure the results definition is a map pointing to defined steps.
    if (step.keys.contains(_keyResults)) {
      if (!(step[_keyResults] is YamlMap)) {
        return ParseResult.malformedResults;
      }

      for (String resultStep in step[_keyResults].values) {
        if (!stepNames.contains(resultStep)) {
          return ParseResult.undefinedResultStep;
        }

        encounteredSteps.add(resultStep);
      }
    }

    return ParseResult.success;
  }

  /// Verifies keys are restricted to the provided list.
  static bool _onlyHasKeys(YamlMap mapping, List<String> keys) {
    for (String key in mapping.keys) {
      if (!keys.contains(key)) {
        return false;
      }
    }

    return true;
  }
}
