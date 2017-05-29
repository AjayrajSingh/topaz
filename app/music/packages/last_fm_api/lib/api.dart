// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show JSON;

import 'package:http/http.dart' as http;
import 'package:last_fm_models/last_fm_models.dart';
import 'package:meta/meta.dart';

const String _kApiBaseUrl = 'ws.audioscrobbler.com';

/// Client for Last FM APIs
class LastFmApi {
  /// Retrieves an artist given the Music Brainz ID (mbid)
  Future<Artist> getArtist(
    @required String mbid,
    @required String apiKey,
  ) async {
    assert(mbid != null);
    assert(apiKey != null);
    Map<String, String> query = {};
    query['method'] = 'artist.getinfo';
    query['mbid'] = mbid;
    query['api_key'] = apiKey;
    query['format'] = 'json';

    Uri uri = new Uri.https(
      _kApiBaseUrl,
      '/2.0/',
      query,
    );

    http.Response response = await http.get(uri);
    if (response.statusCode != 200) {
      return null;
    }
    Map<String, dynamic> json = JSON.decode(response.body);
    return new Artist.fromJson(json['artist']);
  }
}
