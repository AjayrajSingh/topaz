// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JSON;

import 'package:apps.maxwell.services.action_log/component.fidl.dart';
import 'package:apps.maxwell.services.user/intelligence_services.fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

// This module expects to obtain the youtube video id string through the link
// provided from the parent, in the following document id / property key.
const String _kYoutubeDocRoot = 'youtube-doc';
const String _kYoutubeVideoIdKey = 'youtube-video-id';

/// The model class for the youtube_video module.
class YoutubeVideoModuleModel extends ModuleModel {
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
    } else {
      IntelligenceServicesProxy intelligenceServices =
          new IntelligenceServicesProxy();
      moduleContext
          .getIntelligenceServices(intelligenceServices.ctrl.request());
      ComponentActionLogProxy actionLog = new ComponentActionLogProxy();
      intelligenceServices.getActionLog(actionLog.ctrl.request());
      actionLog.logAction('ViewVideo', json);
      intelligenceServices.ctrl.close();
      actionLog.ctrl.close();
      log.fine('_videoId: $_videoId');
      notifyListeners();
    }
  }
}
