// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:application.lib.app.dart/app.dart';
import 'package:apps.maxwell.services.suggestion/proposal.fidl.dart';
import 'package:apps.maxwell.services.suggestion/proposal_publisher.fidl.dart';
import 'package:apps.maxwell.services.suggestion/suggestion_display.fidl.dart';
import 'package:config/config.dart';
import 'package:lib.logging/logging.dart';
import 'package:models/weather.dart';
import 'package:weather_api/weather_api.dart';

// The weather agent is current hardcoded to San Francisco
const double _kDefaultLatitude = 37.7749;
const double _kDefaultLongitude = -122.431297;

final ProposalPublisherProxy _proposalPublisher = new ProposalPublisherProxy();
final ApplicationContext _context = new ApplicationContext.fromStartupInfo();

/// Creates a proposal for the given Spotify artist
Future<Null> _createWeatherProposal({
  double longitude,
  double latitude,
  WeatherApi api,
}) async {
  assert(longitude != null);
  assert(latitude != null);
  assert(api != null);

  Forecast forecast;

  try {
    forecast = await api.getForecastForLocation(
      longitude: longitude,
      latitude: latitude,
    );
  } catch (exception) {
    log.warning('Failed to retrieve weather forecast: ' + exception.toString());
  }

  if (forecast != null) {
    String forecastText =
        '${forecast.temperature.toInt()} °F in ${forecast.locationName}';
    Proposal proposal = new Proposal()
      ..id = 'Weather Forecast'
      ..display = (new SuggestionDisplay()
        ..headline = forecastText
        ..subheadline = '${forecast.description}'
        ..details = ''
        ..color = 0xFFFF0080
        ..iconUrls = <String>[forecast.iconUrlLight]
        ..imageType = SuggestionImageType.other
        ..imageUrl = ''
        ..annoyance = AnnoyanceType.none)
      ..onSelected = <Action>[
        new Action()
          ..createStory = (new CreateStory()
            ..moduleId = 'weather_forecast'
            ..initialData = JSON.encode(<String, dynamic>{
              'longitude': longitude,
              'latitude': latitude,
            }))
      ];
    log.fine('proposing weather suggestion');
    _proposalPublisher.propose(proposal);
  }
}

Future<Null> main(List<dynamic> args) async {
  setupLogger();

  Config config = await Config.read('/system/data/modules/config.json');
  config.validate(<String>['weather_api_key']);
  connectToService(_context.environmentServices, _proposalPublisher.ctrl);

  WeatherApi api = new WeatherApi(apiKey: config.get('weather_api_key'));
  await _createWeatherProposal(
    longitude: _kDefaultLongitude,
    latitude: _kDefaultLatitude,
    api: api,
  );
}
