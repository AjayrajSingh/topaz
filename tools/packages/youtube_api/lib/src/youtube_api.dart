// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:models/youtube.dart';

/// Abstract Youtube API to be used by widgets.
abstract class YoutubeApi {
  /// Gets the [VideoData] for a given Youtube video.
  Future<VideoData> getVideoData({@required String videoId});

  /// Gets the list of related videos for a given Youtube video.
  Future<List<VideoData>> getRelatedVideoData({@required String videoId});

  /// Gets the list of [VideoComment]s for a given Youtube video.
  Future<List<VideoComment>> getCommentsData({@required String videoId});
}
