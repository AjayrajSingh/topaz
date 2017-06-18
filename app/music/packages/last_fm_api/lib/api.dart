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
  /// Last.FM API key
  final String apiKey;

  /// Constructor
  LastFmApi({@required this.apiKey}) {
    assert(apiKey != null);
  }

  /// Retrieves an artist given the name
  Future<Artist> getArtist(String name) async {
    assert(name != null);
    Map<String, String> query = <String, String>{
      'method': 'artist.getinfo',
      'artist': name,
      'api_key': apiKey,
      'format': 'json',
    };

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
