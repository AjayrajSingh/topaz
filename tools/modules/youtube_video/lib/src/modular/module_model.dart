// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JSON;

import 'package:apps.maxwell.services.action_log/component.fidl.dart';
import 'package:apps.maxwell.services.user/intelligence_services.fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';
import 'package:meta/meta.dart';
import 'package:models/youtube.dart';
import 'package:youtube_api/youtube_api.dart';

// This module expects to obtain the youtube video id string through the link
// provided from the parent, in the following document id / property key.
const String _kYoutubeDocRoot = 'youtube-doc';
const String _kYoutubeVideoIdKey = 'youtube-video-id';

// This key is used to add the title to the action log.
const String _kYoutubeVideoTitleKey = 'youtube-video-title';

/// The model class for the youtube_video module.
class YoutubeVideoModuleModel extends ModuleModel {
  /// The Google api key.
  final GoogleApisYoutubeApi youtubeApi;

  /// Creates a new instance of [YoutubeVideoModuleModel].
  YoutubeVideoModuleModel({@required String apiKey})
      : youtubeApi = new GoogleApisYoutubeApi(apiKey: apiKey) {
    assert(apiKey != null);
  }

  /// Gets the Youtube video id.
  String get videoId => _videoId;
  String _videoId;

  @override
  void onNotify(String json) {
    log.fine('onNotify call');

    final dynamic doc = JSON.decode(json);
    try {
      _videoId = doc[_kYoutubeDocRoot][_kYoutubeVideoIdKey];
    } catch (_) {
      try {
        final Map<String, dynamic> contract = doc['view'];
        if (contract['host'] == 'youtu.be') {
          // https://youtu.be/<video id>
          _videoId = contract['path'].substring(1);
        } else {
          // https://www.youtube.com/watch?v=<video id>
          final Map<String, String> params = contract['query parameters'];
          _videoId = params['v'] ?? params['video_ids'];
        }
      } catch (_) {
        _videoId = null;
      }
    }

    if (_videoId == null) {
      log.fine('No youtube video ID found in json.');
      return;
    }

    log.fine('_videoId: $_videoId');

    // Retrieve the title with the youtube api, and log ViewVideo action.
    youtubeApi.getVideoData(videoId: _videoId).then((VideoData data) {
      if (data == null) {
        return;
      }

      Map<String, dynamic> actionLogData = <String, dynamic>{
        _kYoutubeDocRoot: <String, String>{
          _kYoutubeVideoIdKey: data.id,
          _kYoutubeVideoTitleKey: data.title,
        },
      };

      IntelligenceServicesProxy intelligenceServices =
          new IntelligenceServicesProxy();
      moduleContext
          .getIntelligenceServices(intelligenceServices.ctrl.request());
      ComponentActionLogProxy actionLog = new ComponentActionLogProxy();
      intelligenceServices.getActionLog(actionLog.ctrl.request());
      actionLog.logAction('ViewVideo', JSON.encode(actionLogData));
      intelligenceServices.ctrl.close();
      actionLog.ctrl.close();
    });
    notifyListeners();
  }
}
