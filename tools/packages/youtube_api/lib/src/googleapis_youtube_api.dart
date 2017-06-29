// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:googleapis/youtube/v3.dart' as youtube;
import 'package:googleapis_auth/auth_io.dart';
import 'package:meta/meta.dart';
import 'package:models/youtube.dart';

import 'youtube_api.dart';

const int _kRelatedVideoMaxResults = 10;

/// API client for Youtube
///
/// https://developers.google.com/youtube/v3/docs/
class GoogleApisYoutubeApi implements YoutubeApi {
  /// Youtube API key
  final String apiKey;

  final youtube.YoutubeApi _api;

  /// Constructor
  GoogleApisYoutubeApi({@required this.apiKey})
      : _api = new youtube.YoutubeApi(clientViaApiKey(apiKey)) {
    assert(apiKey != null);
  }

  /// Gets the [VideoData] for a given Youtube video.
  ///
  /// https://developers.google.com/youtube/v3/docs/videos
  @override
  Future<VideoData> getVideoData({@required String videoId}) async {
    assert(videoId != null);

    youtube.VideoListResponse response = await _api.videos.list(
      'contentDetails,snippet,statistics',
      id: videoId,
    );

    if (response?.items?.isNotEmpty ?? false) {
      return new VideoData.fromJson(response.items[0].toJson());
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

    youtube.SearchListResponse response = await _api.search.list(
      'snippet',
      relatedToVideoId: videoId,
      maxResults: _kRelatedVideoMaxResults,
      type: 'video',
    );

    if (response?.items?.isNotEmpty ?? false) {
      return response.items
          .map((youtube.SearchResult item) =>
              new VideoData.fromJson(item.toJson()))
          .toList();
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
    assert(videoId != null);

    youtube.CommentThreadListResponse response = await _api.commentThreads.list(
      'id,snippet',
      videoId: videoId,
      order: 'relevance',
      textFormat: 'plainText',
    );

    if (response?.items?.isNotEmpty ?? false) {
      return response.items
          .map((youtube.CommentThread item) =>
              new VideoComment.fromJson(item.toJson()))
          .toList();
    }
    return null;
  }
}
