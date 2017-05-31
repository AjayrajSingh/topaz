// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show BASE64, JSON, UTF8;

import 'package:http/http.dart' as http;
import 'package:music_models/music_models.dart';

const String _kApiBaseUrl = 'api.spotify.com';
const String _kAuthBaseUrl = 'accounts.spotify.com';

/// Client for Spotify APIs
class Api {
  /// Spotify client ID
  final String clientId;

  /// Spotify Client Secret
  final String clientSecret;

  String _accessToken;
  DateTime _expirationTime;

  /// Constructor
  Api({
    this.clientId,
    this.clientSecret,
  }) {
    assert(clientId != null);
    assert(clientSecret != null);
  }

  Future<Map<String, String>> _getAuthHeader() async {
    Map<String, String> authHeader = new Map<String, String>();
    if (_accessToken != null &&
        _expirationTime != null &&
        _expirationTime.isBefore(new DateTime.now())) {
      authHeader['Authorization'] = 'Bearer $_accessToken';
      return authHeader;
    } else {
      Uri uri = new Uri.https(_kAuthBaseUrl, '/api/token');
      Map<String, String> headers = new Map<String, String>();
      String encodedAuthorization =
          BASE64.encode(UTF8.encode('$clientId:$clientSecret'));
      headers['Authorization'] = 'Basic $encodedAuthorization';
      Map<String, String> body = new Map<String, String>();
      body['grant_type'] = 'client_credentials';
      http.Response response =
          await http.post(uri, body: body, headers: headers);
      if (response.statusCode != 200) {
        return null;
      }
      dynamic jsonData = JSON.decode(response.body);
      if (jsonData['access_token'] is String && jsonData['expires_in'] is int) {
        _accessToken = jsonData['access_token'];
        _expirationTime = new DateTime.now()
            .add(new Duration(seconds: jsonData['expires_in']));
        authHeader['Authorization'] = 'Bearer $_accessToken';
        return authHeader;
      } else {
        return null;
      }
    }
  }

  /// Retrieves given artist based on id
  Future<Artist> getArtistById(String id) async {
    Map<String, String> authHeader = await _getAuthHeader();
    if (authHeader == null) {
      return null;
    }
    Uri uri = new Uri.https(_kApiBaseUrl, '/v1/artists/$id');
    http.Response response = await http.get(uri, headers: authHeader);
    if (response.statusCode != 200) {
      return null;
    }
    return new Artist.fromJson(JSON.decode(response.body));
  }

  /// Retrieves related artists for given artist id
  Future<List<Artist>> getRelatedArtists(String id) async {
    Map<String, String> authHeader = await _getAuthHeader();
    if (authHeader == null) {
      return null;
    }
    Uri uri = new Uri.https(_kApiBaseUrl, '/v1/artists/$id/related-artists');
    http.Response response = await http.get(uri, headers: authHeader);
    if (response.statusCode != 200) {
      return null;
    }
    dynamic jsonData = JSON.decode(response.body);
    List<Artist> artists = <Artist>[];
    if (jsonData['artists'] is List<dynamic>) {
      jsonData['artists'].forEach((dynamic artistJson) {
        artists.add(new Artist.fromJson(artistJson));
      });
    }
    return artists;
  }

  /// Retrieves the given album based on id
  Future<Album> getAlbumById(String id) async {
    Map<String, String> authHeader = await _getAuthHeader();
    if (authHeader == null) {
      return null;
    }
    Uri uri = new Uri.https(_kApiBaseUrl, '/v1/albums/$id');
    http.Response response = await http.get(uri, headers: authHeader);
    if (response.statusCode != 200) {
      return null;
    }
    return new Album.fromJson(JSON.decode(response.body));
  }

  /// Retreives albums for given artist id
  Future<List<Album>> getAlbumsForArtist(String id) async {
    Map<String, String> authHeader = await _getAuthHeader();
    if (authHeader == null) {
      return null;
    }
    // Only retrieve albums for US market to avoid duplicates
    Map<String, String> query = new Map<String, String>();
    query['market'] = 'us';
    Uri uri = new Uri.https(_kApiBaseUrl, '/v1/artists/$id/albums', query);
    http.Response response = await http.get(uri, headers: authHeader);
    if (response.statusCode != 200) {
      return null;
    }
    dynamic jsonData = JSON.decode(response.body);
    List<Album> simplifiedAlbums = <Album>[];
    if (jsonData['items'] is List<dynamic>) {
      jsonData['items'].forEach((dynamic albumJson) {
        simplifiedAlbums.add(new Album.fromJson(albumJson));
      });
    }
    // We only get simplified album data (no track list), so an additional query
    // must be made to retrieve the full data for each album.
    List<String> albumIds =
        simplifiedAlbums.map((Album album) => album.id).toList();
    return getAlbumsById(albumIds);
  }

  /// Retrieve list of albums given a list of album IDs
  Future<List<Album>> getAlbumsById(List<String> ids) async {
    Map<String, String> authHeader = await _getAuthHeader();
    if (authHeader == null) {
      return null;
    }
    Map<String, String> query = new Map<String, String>();
    query['ids'] = ids.join(',');
    Uri uri = new Uri.https(_kApiBaseUrl, '/v1/albums', query);
    http.Response response = await http.get(uri, headers: authHeader);
    if (response.statusCode != 200) {
      return null;
    }
    dynamic jsonData = JSON.decode(response.body);
    List<Album> albums = <Album>[];
    if (jsonData['albums'] is List<dynamic>) {
      jsonData['albums'].forEach((dynamic albumJson) {
        albums.add(new Album.fromJson(albumJson));
      });
    }
    return albums;
  }
}
