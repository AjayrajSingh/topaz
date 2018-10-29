// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl;
import 'package:fuchsia_modular/src/module/internal/_fidl_transformers.dart';
import 'package:fuchsia_modular/src/module/internal/_entity_intent_parameter_data_transformer.dart';
import 'package:test/test.dart';

import '../../matchers.dart';

void main() {
  group('intent transformers', () {
    test('convertFidlIntentToIntent clones correct fields', () {
      final fidlIntent = fidl.Intent(
        action: 'my-action',
        handler: 'my-handler',
        parameters: [
          fidl.IntentParameter(
              name: 'intent-param',
              data: fidl.IntentParameterData.withEntityReference('entity-ref')),
        ],
      );
      final intent = convertFidlIntentToIntent(fidlIntent);
      expect(intent.action, fidlIntent.action);
      expect(intent.handler, fidlIntent.handler);
      expect(intent.parameters, fidlIntent.parameters);
    });

    test('convertFidlIntentToIntent handles null fidl intent parametsrs', () {
      final fidlIntent = fidl.Intent(
        action: 'my-action',
        parameters: null,
      );
      final intent = convertFidlIntentToIntent(fidlIntent);
      expect(intent.parameters, isNotNull);
    });

    test('Intents with const parameter lists can still be modified', () {
      final fidlIntent = fidl.Intent(
        action: 'action',
        parameters: const [],
      );
      // Should be able to modify the parameters on the intent.
      // note: there are helper methods for this task but we want to
      // isolate the test to checking for mutability and not the helper methods.
      convertFidlIntentToIntent(fidlIntent).parameters.add(fidl.IntentParameter(
          name: 'intent-param',
          data: fidl.IntentParameterData.withEntityReference('entity-ref')));
    });
  });

  group('intent parameter transformers', () {
    test('convertFidlIntentParameterToIntentParameter clones all fields', () {
      final fidlIntentParameter = fidl.IntentParameter(
        name: 'foo',
        data: fidl.IntentParameterData.withEntityReference('entity-ref'),
      );
      final intentParameter =
          convertFidlIntentParameterToIntentParameter(fidlIntentParameter);
      expect(intentParameter.name, fidlIntentParameter.name);
      expect(intentParameter.data, fidlIntentParameter.data);
      expect(intentParameter.dataTransformer, isNotNull);
    });

    test(
        'convertFidlIntentParameterToIntentParameter throws for unsupported data type',
        () {
      final fidlIntentParameter = fidl.IntentParameter(
        name: 'foo',
        data: fidl.IntentParameterData.withLinkName('my-link'),
      );
      expect(() {
        convertFidlIntentParameterToIntentParameter(fidlIntentParameter);
      }, throwsModuleStateException);
    });

    test(
        'convertFidlIntentParameterToIntentParameter uses correct data transformer for entity ref',
        () {
      final fidlIntentParameter = fidl.IntentParameter(
        name: 'foo',
        data: fidl.IntentParameterData.withEntityReference('ref'),
      );
      expect(
          convertFidlIntentParameterToIntentParameter(fidlIntentParameter)
              .dataTransformer,
          const TypeMatcher<EntityIntentParameterDataTransformer>());
    });
  });
}
