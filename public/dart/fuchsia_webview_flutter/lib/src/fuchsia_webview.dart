// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:fuchsia_scenic_flutter/child_view.dart' show ChildView;
import 'package:webview_flutter/platform_interface.dart';

import 'fuchsia_web_services.dart';
import 'fuchsia_webview_platform_controller.dart';

/// Builds an Fuchsia webview.
class FuchsiaWebView implements WebViewPlatform {
  /// The fuchsia implementation of [WebViewPlatformController]
  FuchsiaWebServices fuchsiaWebServices;

  /// This constructor should only be used to inject a platform controller for
  /// testing.
  ///
  /// TODO(nkorsote): hide this implementation detail
  @visibleForTesting
  FuchsiaWebView({this.fuchsiaWebServices});

  @override
  Widget build({
    @required WebViewPlatformCallbacksHandler webViewPlatformCallbacksHandler,
    BuildContext context,
    CreationParams creationParams,
    WebViewPlatformCreatedCallback onWebViewPlatformCreated,
    Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers,
  }) {
    assert(webViewPlatformCallbacksHandler != null);
    return _EmbeddedWebview(
      webViewPlatformCallbacksHandler: webViewPlatformCallbacksHandler,
      creationParams: creationParams,
      onWebViewPlatformCreated: onWebViewPlatformCreated,
      fuchsiaWebServices: fuchsiaWebServices,
    );
  }

  @override
  Future<bool> clearCookies() =>
      FuchsiaWebViewPlatformController.clearCookies();
}

class _EmbeddedWebview extends StatefulWidget {
  final WebViewPlatformCallbacksHandler webViewPlatformCallbacksHandler;
  final CreationParams creationParams;
  final WebViewPlatformCreatedCallback onWebViewPlatformCreated;
  final FuchsiaWebServices fuchsiaWebServices;

  const _EmbeddedWebview({
    this.webViewPlatformCallbacksHandler,
    this.creationParams,
    this.onWebViewPlatformCreated,
    this.fuchsiaWebServices,
  });
  @override
  _EmbeddedWebviewState createState() => _EmbeddedWebviewState();
}

class _EmbeddedWebviewState extends State<_EmbeddedWebview> {
  FuchsiaWebViewPlatformController _controller;

  @override
  Widget build(BuildContext context) =>
      ChildView(connection: _controller.fuchsiaWebServices.childViewConnection);

  @override
  void initState() {
    super.initState();
    _controller = FuchsiaWebViewPlatformController(
        widget.webViewPlatformCallbacksHandler,
        widget.creationParams,
        widget.fuchsiaWebServices);
    widget.onWebViewPlatformCreated?.call(_controller);
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }
}
