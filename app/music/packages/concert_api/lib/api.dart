// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show JSON;

import 'package:concert_models/concert_models.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

const String _kApiBaseUrl = 'api.songkick.com';

/// Client for Songkick APIs
class Api {
  /// Searches for Songkick artists given a name
  static Future<List<Artist>> searchArtist(
    @required String name,
    @required String apiKey,
  ) async {
    assert(name != null);
    assert(apiKey != null);
    Map<String, String> query = new Map<String, String>();
    query['query'] = name;
    query['apikey'] = apiKey;
    Uri uri = new Uri.https(
      _kApiBaseUrl,
      '/api/3.0/search/artists.json',
      query,
    );
    http.Response response = await http.get(uri);
    if (response.statusCode != 200) {
      return null;
    }
    dynamic jsonData = JSON.decode(response.body);
    List<Artist> artists = <Artist>[];
    if (jsonData['resultsPage'] is Map<String, dynamic> &&
        jsonData['resultsPage']['status'] == 'ok' &&
        jsonData['resultsPage']['results'] is Map<String, dynamic> &&
        jsonData['resultsPage']['results']['artist']
            is List<Map<String, dynamic>>) {
      jsonData['resultsPage']['results']['artist']
          .forEach((Map<String, dynamic> artistJson) {
        artists.add(new Artist.fromJson(artistJson));
      });
    }
    return artists;
  }

  /// List upcoming Songkick events for the given artist name.
  /// Only nearby (based on client IP address) events will shown.
  static Future<List<Event>> searchEventsByArtist(
    @required String name,
    @required String apiKey,
  ) async {
    assert(name != null);
    assert(apiKey != null);
    Map<String, String> query = new Map<String, String>();
    query['artist_name'] = name;
    query['location'] = 'clientip';
    query['apikey'] = apiKey;
    Uri uri = new Uri.https(
      _kApiBaseUrl,
      '/api/3.0/events.json',
      query,
    );
    http.Response response = await http.get(uri);
    if (response.statusCode != 200) {
      return null;
    }
    dynamic jsonData = JSON.decode(response.body);
    List<Event> events = <Event>[];
    if (jsonData['resultsPage'] is Map<String, dynamic> &&
        jsonData['resultsPage']['status'] == 'ok' &&
        jsonData['resultsPage']['results'] is Map<String, dynamic> &&
        jsonData['resultsPage']['results']['event']
            is List<Map<String, dynamic>>) {
      jsonData['resultsPage']['results']['event']
          .forEach((Map<String, dynamic> eventJson) {
        events.add(new Event.fromJson(eventJson));
      });
    }
    return events;
  }

  /// Retrieves a single Songkick event based on the id.
  static Future<Event> getEvent(int id, String apiKey) async {
    assert(id != null);
    assert(apiKey != null);
    Map<String, String> query = new Map<String, String>();
    query['apikey'] = apiKey;
    Uri uri = new Uri.https(
      _kApiBaseUrl,
      '/api/3.0/events/$id.json',
      query,
    );
    http.Response response = await http.get(uri);
    if (response.statusCode != 200) {
      return null;
    }
    dynamic jsonData = JSON.decode(response.body);
    if (jsonData['resultsPage'] is Map<String, dynamic> &&
        jsonData['resultsPage']['status'] == 'ok' &&
        jsonData['resultsPage']['results'] is Map<String, dynamic> &&
        jsonData['resultsPage']['results']['event'] is Map<String, dynamic>) {
      return new Event.fromJson(jsonData['resultsPage']['results']['event']);
    } else {
      return null;
    }
  }
}
