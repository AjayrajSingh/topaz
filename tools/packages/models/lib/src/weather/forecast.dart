// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Material Design Weather Icons from https://material.io/icons/
final Map<String, String> _weatherIcons = <String, String>{
  '01d':
      'https://www.gstatic.com/images/branding/product/2x/sunny_light_96dp.png',
  '02d':
      'https://www.gstatic.com/images/branding/product/2x/mostly_cloudy_day_dark_96dp.png',
  '03d':
      'https://www.gstatic.com/images/branding/product/2x/cloudy_dark_96dp.png',
  '04d':
      'https://www.gstatic.com/images/branding/product/2x/partly_cloudy_dark_96dp.png',
  '09d':
      'https://www.gstatic.com/images/branding/product/2x/heavy_rain_dark_96dp.png',
  '10d':
      'https://www.gstatic.com/images/branding/product/2x/scattered_showers_day_dark_96dp.png',
  '11d':
      'https://www.gstatic.com/images/branding/product/2x/strong_tstorms_dark_96dp.png',
  '13d':
      'https://www.gstatic.com/images/branding/product/2x/wintry_mix_rain_snow_dark_96dp.png',
  '50d':
      'https://www.gstatic.com/images/branding/product/2x/haze_fog_dust_smoke_dark_96dp.png',
  '01n':
      'https://www.gstatic.com/images/branding/product/2x/clear_night_dark_96dp.png',
  '02n':
      'https://www.gstatic.com/images/branding/product/2x/mostly_cloudy_night_dark_96dp.png',
  '03n':
      'https://www.gstatic.com/images/branding/product/2x/partly_cloudy_night_dark_96dp.png',
  '04n':
      'https://www.gstatic.com/images/branding/product/2x/mostly_clear_night_dark_96dp.png',
  '09n':
      'https://www.gstatic.com/images/branding/product/2x/heavy_rain_dark_96dp.png',
  '10n':
      'https://www.gstatic.com/images/branding/product/2x/scattered_showers_night_dark_96dp.png',
  '11n':
      'https://www.gstatic.com/images/branding/product/2x/isolated_scattered_tstorms_night_dark_96dp.png',
  '13n':
      'https://www.gstatic.com/images/branding/product/2x/scattered_snow_showers_night_dark_96dp.png',
  '50n':
      'https://www.gstatic.com/images/branding/product/2x/haze_fog_dust_smoke_dark_96dp.png',
};

/// Represents a weather forecast for a given location
///
/// See https://openweathermap.org
class Forecast {
  /// Tempature in Imperial units
  final double temperature;

  /// Main status of the weather
  ///
  /// ex. 'Clear'
  final String mainStatus;

  /// Detailed description of the weather
  ///
  /// ex. 'clear sky'
  final String description;

  /// Icon id by openweathermap.org for represent the current weather
  final String iconId;

  /// General location name
  ///
  /// ex. San Francisco
  final String locationName;

  /// Constructor
  Forecast({
    this.temperature,
    this.mainStatus,
    this.description,
    this.iconId,
    this.locationName,
  });

  /// Creates an Event from JSON data
  factory Forecast.fromJson(Map<String, dynamic> json) {
    return new Forecast(
      temperature: json['main']['temp'],
      mainStatus: json['weather'][0]['main'],
      description: json['weather'][0]['description'],
      iconId: json['weather'][0]['icon'],
      locationName: json['name'],
    );
  }

  /// Get URL for weather icon
  String get iconUrl =>
      _weatherIcons.containsKey(iconId) ? _weatherIcons[iconId] : null;
}
