// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JSON;

import 'package:application.services/service_provider.fidl.dart';
import 'package:apps.modular.services.module/module_context.fidl.dart';
import 'package:apps.modular.services.module/module_controller.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

const String _kYoutubeDocRoot = 'youtube-doc';
const String _kYoutubeVideoIdKey = 'youtube-video-id';

const String _kChildUrl = 'file:///system/apps/youtube_thumbnail';
const String _kVideoPlayerUrl = 'file:///system/apps/youtube_video';
const String _kRelatedVideoUrl = 'file:///system/apps/youtube_related_videos';

// The youtube video id.
// TODO(youngseokyoon): remove this hard-coded value.
// https://fuchsia.atlassian.net/browse/SO-483
final String _kVideoId = 'p336IIjZCl8';

/// The model class for the youtuve_story module.
class YoutubeStoryModuleModel extends ModuleModel {
  /// Gets the [ChildViewConnection] to the video player child module.
  ChildViewConnection get videoPlayerConn => _videoPlayerConn;
  ChildViewConnection _videoPlayerConn;

  /// Gets the [ChildViewConnection] to the related videos child module.
  ChildViewConnection get relatedVideoConn => _relatedVideoConn;
  ChildViewConnection _relatedVideoConn;

  @override
  void onReady(
    ModuleContext moduleContext,
    Link link,
    ServiceProvider incomingServiceProvider,
  ) {
    super.onReady(moduleContext, link, incomingServiceProvider);

    Map<String, dynamic> doc = <String, dynamic>{
      _kYoutubeVideoIdKey: _kVideoId
    };
    link.updateObject(<String>[_kYoutubeDocRoot], JSON.encode(doc));

    // Spawn the child.
    _videoPlayerConn =
        new ChildViewConnection(startModule(url: _kVideoPlayerUrl));
    _relatedVideoConn =
        new ChildViewConnection(startModule(url: _kRelatedVideoUrl));
    notifyListeners();
  }

  /// Start a module and return its [ViewOwner] handle.
  InterfaceHandle<ViewOwner> startModule({
    String url,
    InterfaceHandle<ServiceProvider> outgoingServices,
    InterfaceRequest<ServiceProvider> incomingServices,
  }) {
    InterfacePair<ViewOwner> viewOwnerPair = new InterfacePair<ViewOwner>();
    InterfacePair<ModuleController> moduleControllerPair =
        new InterfacePair<ModuleController>();

    log.fine('Starting sub-module: $url');
    moduleContext.startModule(
      url, // module name
      url,
      null, // Pass our default link to our child
      outgoingServices,
      incomingServices,
      moduleControllerPair.passRequest(),
      viewOwnerPair.passRequest(),
    );
    log.fine('Started sub-module: $url');

    return viewOwnerPair.passHandle();
  }
}
