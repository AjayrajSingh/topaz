// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl/src/interface.dart';
import 'package:fidl_fuchsia_setui/fidl.dart';
import 'package:fidl_fuchsia_stash/fidl.dart';
import 'package:lib_setui_service/src/intl_controller.dart';
import 'package:lib_setui_service/src/intl/intl_settings_util.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

// ignore_for_file: implementation_imports

const String _stashKey = IntlSettingsController.stashKey;

void main() async {
  IntlSettingsController controller;
  _MockStoreAccessorWrapper storeAccessorWrapper;
  _FakeStoreAccessor storeAccessor;

  setUp(() {
    storeAccessor = _FakeStoreAccessor();
    storeAccessorWrapper = _MockStoreAccessorWrapper();
    when(storeAccessorWrapper.accessor).thenReturn(storeAccessor);
    StoreAccessorWrapper provider() => storeAccessorWrapper;
    controller = IntlSettingsController.withStashProvider(provider);
  });

  group('Intl controller', () {
    test('initialize() reads existing settings from Stash', () {
      const IntlSettings settings = IntlSettings(
          locales: ['en-US', 'es-MX'],
          hourCycle: HourCycle.h23,
          temperatureUnit: TemperatureUnit.fahrenheit);

      storeAccessor
        ..setValue(_stashKey, Value.withStringval(toJson(settings)))
        ..commit();

      controller.initialize();
      const SettingsObject expected = SettingsObject(
          settingType: SettingType.intl, data: SettingData.withIntl(settings));
      expect(expected, equals(controller.value));
    });

    test('applyMutation() writes to Stash', () {
      const IntlSettings initialSettings = IntlSettings(
          locales: ['en-US', 'es-MX'],
          hourCycle: HourCycle.h23,
          temperatureUnit: TemperatureUnit.fahrenheit);

      storeAccessor
        ..setValue(_stashKey, Value.withStringval(toJson(initialSettings)))
        ..commit();

      controller
        ..initialize()
        ..applyMutation(Mutation.withLocalesMutationValue(
            LocalesMutation(locales: ['en-US', 'es-MX', 'fr-FR'])));

      final expected = Value.withStringval(toJson(IntlSettings(
          locales: ['en-US', 'es-MX', 'fr-FR'],
          hourCycle: HourCycle.h23,
          temperatureUnit: TemperatureUnit.fahrenheit)));
      expect(storeAccessor.getValueDirectly(_stashKey), equals(expected));
    });

    test('close() closes Stash channels', () {
      bool isClosed = false;
      void stubClose() {
        isClosed = true;
      }

      when(storeAccessorWrapper.close).thenReturn(stubClose);

      controller
        ..initialize()
        ..close();

      expect(isClosed, isTrue);
    });
  });
}

/// Fake implementation of [StoreAccessor] (synchronous) that just uses
/// in-memory maps.
class _FakeStoreAccessor implements StoreAccessor {
  Map<String, Value> committedValues = {};
  Map<String, Value> pendingValues = {};

  @override
  void getValue(String key, void Function(Value val) callback) {
    callback(getValueDirectly(key));
  }

  /// Get a value without using a callback.
  Value getValueDirectly(String key) {
    return committedValues[key];
  }

  @override
  void setValue(String key, Value val) {
    pendingValues[key] = val;
  }

  @override
  void commit() {
    committedValues.addAll(pendingValues);
    pendingValues.clear();
  }

  @override
  void deletePrefix(String prefix) {
    throw UnimplementedError();
  }

  @override
  void deleteValue(String key) {
    throw UnimplementedError();
  }

  @override
  void getPrefix(String prefix, InterfaceRequest<GetIterator> it) {
    throw UnimplementedError();
  }

  @override
  void listPrefix(String prefix, InterfaceRequest<ListIterator> it) {
    throw UnimplementedError();
  }
}

class _MockStoreAccessorWrapper extends Mock implements StoreAccessorWrapper {}
