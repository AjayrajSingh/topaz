// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_setui/fidl.dart';
import 'package:test/test.dart';
import 'package:lib_setui_service/src/intl/intl_settings_util.dart' as util;

// ignore_for_file: implementation_imports

void main() {
  group('Intl settings util', () {
    test('setLocales() works', () {
      const before = IntlSettings(
          locales: ['en-US', 'es-MX', 'fr-FR', 'ru-RU'],
          hourCycle: HourCycle.h12,
          temperatureUnit: TemperatureUnit.celsius);
      const expected = IntlSettings(
          locales: ['en-US', 'fr-FR', 'ru-RU', 'es-MX'],
          hourCycle: HourCycle.h12,
          temperatureUnit: TemperatureUnit.celsius);
      expect(
          util.setLocales(before,
              LocalesMutation(locales: ['en-US', 'fr-FR', 'ru-RU', 'es-MX'])),
          equals(expected));
    });

    test('setHourCycle() works', () {
      const before = IntlSettings(
          locales: ['en-US', 'es-MX'],
          hourCycle: HourCycle.h12,
          temperatureUnit: TemperatureUnit.celsius);
      const expected = IntlSettings(
          locales: ['en-US', 'es-MX'],
          hourCycle: HourCycle.h23,
          temperatureUnit: TemperatureUnit.celsius);
      expect(
          util.setHourCycle(
              before, HourCycleMutation(hourCycle: HourCycle.h23)),
          equals(expected));
    });

    test('setTemperatureUnit() works', () {
      const before = IntlSettings(
          locales: ['en-US', 'es-MX'],
          hourCycle: HourCycle.h12,
          temperatureUnit: TemperatureUnit.celsius);
      const expected = IntlSettings(
          locales: ['en-US', 'es-MX'],
          hourCycle: HourCycle.h12,
          temperatureUnit: TemperatureUnit.fahrenheit);
      expect(
          util.setTemperatureUnit(
              before,
              TemperatureUnitMutation(
                  temperatureUnit: TemperatureUnit.fahrenheit)),
          equals(expected));
    });

    test('toJson() works', () {
      const settings = IntlSettings(
          locales: ['en-US', 'es-MX'],
          hourCycle: HourCycle.h23,
          temperatureUnit: TemperatureUnit.fahrenheit);
      const expected =
          '{"locales":["en-US","es-MX"],"hour_cycle":"h23","temperature_unit":"fahrenheit"}';
      expect(util.toJson(settings), equals(expected));
    });

    test('fromJson() works', () {
      const json = '''
      {
        "locales": ["en-US", "es-MX"],
        "hour_cycle": "h23",
        "temperature_unit": "fahrenheit"
      }
      ''';
      const expected = IntlSettings(
          locales: ['en-US', 'es-MX'],
          hourCycle: HourCycle.h23,
          temperatureUnit: TemperatureUnit.fahrenheit);
      expect(util.fromJson(json), equals(expected));
    });
  });
}
