// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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

  /// Constructor
  Forecast({
    this.temperature,
    this.mainStatus,
    this.description,
    this.iconId,
  });

  /// Creates an Event from JSON data
  factory Forecast.fromJson(Map<String, dynamic> json) {
    return new Forecast(
      temperature: json['main']['temp'],
      mainStatus: json['weather'][0]['main'],
      description: json['weather'][0]['description'],
      iconId: json['weather'][0]['icon'],
    );
  }

  /// Get URL for weather icon
  Uri get iconUrl => Uri.parse('http://openweathermap.org/img/w/$iconId.png');
}
