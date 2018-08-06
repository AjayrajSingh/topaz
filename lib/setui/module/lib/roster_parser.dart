// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';
import 'package:yaml/yaml.dart';

import 'module_action.dart';
import 'module_action_repository.dart';

/// Results that can be returned during validation.
enum ParseResult {
  success,
  malformedDoc,
  malformedStep,
  missingAttr,
  malformedAttr
}

/// Parser for module-based roster.
class RosterParser {
  static const String _keyVerb = 'verb';
  static const String _keyHandler = 'handler';

  static final List<String> _requiredKeys = [_keyVerb, _keyHandler];

  ModuleActionRepository parse(YamlDocument config) {
    if (validate(config) != ParseResult.success) {
      return null;
    }

    final YamlMap steps = config.contents.value;
    final Map<String, ModuleAction> actions = {};

    for (final String key in steps.keys) {
      actions[key] =
          new ModuleAction(key, steps[key][_keyVerb], steps[key][_keyHandler]);
    }

    return new ModuleActionRepository(actions);
  }

  /// Ensures the input configuration file is properly formatted. Upon success,
  /// [ParseResult.success] will be returned. Otherwise, the appropriate error
  /// will be returned.
  @visibleForTesting
  static ParseResult validate(YamlDocument config) {
    if (!(config != null && config.contents.value is YamlMap)) {
      return ParseResult.malformedDoc;
    }

    final YamlMap steps = config.contents.value;

    for (String key in steps.keys) {
      if (!(steps[key] is YamlMap &&
          steps[key].length == _requiredKeys.length)) {
        return ParseResult.malformedStep;
      }

      final YamlMap attrs = steps[key];

      for (String key in _requiredKeys) {
        if (!attrs.keys.contains(key)) {
          return ParseResult.missingAttr;
        }

        if (!(attrs[key] is String)) {
          return ParseResult.malformedAttr;
        }
      }
    }

    return ParseResult.success;
  }
}
