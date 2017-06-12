// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JSON;

import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

// This module expects to obtain the youtube video id string through the link
// provided from the parent, in the following document id / property key.
// The JSON string in the Link looks something like this:
// { "youtube-doc" : { "youtube-video-id" : "https://www.youtube.com/blah" } }
const String _kYoutubeDocRoot = 'youtube-doc';
const String _kYoutubeVideoIdKey = 'youtube-video-id';

/// The model class for the youtube_thumbnail module.
class YoutubeThumbnailModuleModel extends ModuleModel {
  /// Gets the Youtube video id.
  String get videoId => _videoId;
  String _videoId;

  @override
  void onNotify(String json) {
    log.fine('onNotify call');

    final dynamic doc = JSON.decode(json);
    if (doc is! Map ||
        doc[_kYoutubeDocRoot] is! Map ||
        doc[_kYoutubeDocRoot][_kYoutubeVideoIdKey] is! String) {
      log.fine('No youtube key found in json.');
      return;
    }

    _videoId = doc[_kYoutubeDocRoot][_kYoutubeVideoIdKey];

    log.fine('_videoId: $_videoId');
    notifyListeners();
  }
}
