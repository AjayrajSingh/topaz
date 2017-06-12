// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show JSON;

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:models/youtube.dart';

import 'youtube_api.dart';

const String _kApiBaseUrl = 'content.googleapis.com';

const String _kRelatedVideoMaxResults = '10';

/// API client for Youtube
///
/// https://developers.google.com/youtube/v3/docs/
// TODO(youngseokyoon): use googleapis package
class HttpsYoutubeApi implements YoutubeApi {
  /// Youtube API key
  final String apiKey;

  /// Constructor
  HttpsYoutubeApi({@required this.apiKey}) {
    assert(apiKey != null);
  }

  /// Gets the [VideoData] for a given Youtube video.
  ///
  /// https://developers.google.com/youtube/v3/docs/videos
  @override
  Future<VideoData> getVideoData({@required String videoId}) async {
    assert(videoId != null);
    Map<String, String> params = <String, String>{
      'id': videoId,
      'key': apiKey,
      'part': 'contentDetails,snippet,statistics',
    };

    Uri uri = new Uri.https(_kApiBaseUrl, '/youtube/v3/videos', params);
    http.Response response = await http.get(uri);
    if (response.statusCode != 200) {
      return null;
    }
    dynamic jsonData = JSON.decode(response.body);

    if (jsonData['items'] is List<Map<String, dynamic>> &&
        jsonData['items'].isNotEmpty) {
      return new VideoData.fromJson(jsonData['items'][0]);
    }
    return null;
  }

  /// Gets the list of related videos for a given Youtube video.
  ///
  /// https://developers.google.com/youtube/v3/docs/search
  @override
  Future<List<VideoData>> getRelatedVideoData({
    @required String videoId,
  }) async {
    assert(videoId != null);
    Map<String, String> params = <String, String>{
      'part': 'snippet',
      'relatedToVideoId': videoId,
      'maxResults': _kRelatedVideoMaxResults,
      'type': 'video',
      'key': apiKey,
    };

    Uri uri = new Uri.https(_kApiBaseUrl, '/youtube/v3/search', params);
    http.Response response = await http.get(uri);
    if (response.statusCode != 200) {
      return null;
    }

    dynamic jsonData = JSON.decode(response.body);

    if (jsonData['items'] is List<Map<String, dynamic>>) {
      return jsonData['items'].map((dynamic json) {
        return new VideoData.fromJson(json);
      }).toList();
    }
    return null;
  }

  /// Gets the comments data for a given Youtube video.
  ///
  /// https://developers.google.com/youtube/v3/docs/commentThreads
  @override
  Future<List<VideoComment>> getCommentsData({
    @required String videoId,
  }) async {
    Map<String, String> params = <String, String>{
      'videoId': videoId,
      'key': apiKey,
      'part': 'id,snippet',
      'order': 'relevance',
      'textFormat': 'plainText',
    };

    Uri uri = new Uri.https(_kApiBaseUrl, '/youtube/v3/commentThreads', params);
    http.Response response = await http.get(uri);
    if (response.statusCode != 200) {
      return null;
    }
    dynamic jsonData = JSON.decode(response.body);

    if (jsonData['items'] is List<dynamic>) {
      return jsonData['items']
          .map((dynamic json) => new VideoComment.fromJson(json))
          .toList();
    } else {
      return null;
    }
  }
}
