// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Utility methods for working with the [IntlSettings] FIDL struct.
library intl_settings_util;

import 'dart:convert';
import 'package:fidl_fuchsia_setui/fidl.dart';

IntlSettings applyMutation(IntlSettings settings, Mutation mutation) {
  switch (mutation.tag) {
    case MutationTag.localesMutationValue:
      return setLocales(settings, mutation.localesMutationValue);
    case MutationTag.hourCycleMutationValue:
      return setHourCycle(settings, mutation.hourCycleMutationValue);
    case MutationTag.temperatureUnitMutationValue:
      return setTemperatureUnit(
          settings, mutation.temperatureUnitMutationValue);
    default:
      throw ArgumentError('Unsupported mutation type');
  }
}

IntlSettings setLocales(IntlSettings settings, LocalesMutation mutation) {
  return IntlSettings(
      locales: mutation.locales,
      hourCycle: settings.hourCycle,
      temperatureUnit: settings.temperatureUnit);
}

IntlSettings setHourCycle(IntlSettings settings, HourCycleMutation mutation) {
  if (settings.hourCycle != mutation.hourCycle) {
    return IntlSettings(
        locales: settings.locales,
        hourCycle: mutation.hourCycle,
        temperatureUnit: settings.temperatureUnit);
  }
  return settings;
}

IntlSettings setTemperatureUnit(
    IntlSettings settings, TemperatureUnitMutation mutation) {
  if (settings.temperatureUnit != mutation.temperatureUnit) {
    return IntlSettings(
        locales: settings.locales,
        hourCycle: settings.hourCycle,
        temperatureUnit: mutation.temperatureUnit);
  }
  return settings;
}

/// JSON encoder, since there's no standard one for FIDL.
String toJson(IntlSettings settings) {
  Map<String, dynamic> map = {
    'locales': settings.locales,
    'hour_cycle': settings.hourCycle == HourCycle.h12 ? 'h12' : 'h23',
    'temperature_unit': settings.temperatureUnit == TemperatureUnit.celsius
        ? 'celsius'
        : 'fahrenheit'
  };
  return jsonEncode(map);
}

/// JSON decoder, since there's no standard one for FIDL.
IntlSettings fromJson(String json) {
  Map<String, dynamic> parsed = jsonDecode(json);
  return IntlSettings(
      locales: List<String>.from(parsed['locales']),
      hourCycle: HourCycle.valuesMap[parsed['hour_cycle']],
      temperatureUnit: TemperatureUnit.valuesMap[parsed['temperature_unit']]);
}
