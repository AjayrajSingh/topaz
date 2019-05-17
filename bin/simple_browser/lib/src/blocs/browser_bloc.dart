// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:fuchsia_logger/logger.dart';
import 'package:fidl_fuchsia_web/fidl_async.dart' as web;
import 'package:meta/meta.dart';
import 'package:webview/webview.dart';
import '../models/browse_action.dart';

// Business logic for the browser.
// Sinks:
//   BrowseAction: a browsing action - url request, prev/next page, etc.
// Streams:
//   Url: streams the url in case of an in page navigation.
class BrowserBloc extends web.NavigationEventListener {
  final ChromiumWebView webView;

  // State storage for browsing with back/forward buttons.
  // Stores the browsing history.
  final _urlList = <String>[];
  // Stores the current location of the browser WRT history.
  int _urlListHead = -1;
  // True when the most recent navigation used back/forward buttons, false
  // otherwise.
  bool _navigationOngoing = false;

  // Streams
  final _urlController = StreamController<String>.broadcast();
  Stream<String> get url => _urlController.stream;
  final _forwardController = StreamController<bool>.broadcast();
  Stream<bool> get forwardState => _forwardController.stream;
  final _backController = StreamController<bool>.broadcast();
  Stream<bool> get backState => _backController.stream;

  // Sinks
  final _browseActionController = StreamController<BrowseAction>();
  Sink<BrowseAction> get request => _browseActionController.sink;

  BrowserBloc({
    @required this.webView,
    String homePage,
  }) : assert(webView != null) {
    webView.setNavigationEventListener(this);

    if (homePage != null) {
      _handleAction(NavigateToAction(url: homePage));
    }
    _browseActionController.stream.listen(_handleAction);
  }

  @override
  Future<Null> onNavigationStateChanged(web.NavigationState event) async {
    log.info('url loaded: ${event.url}');
    if (!_navigationOngoing) {
      // The event was triggered by a navigation inside the page.
      await _addUrl(event.url);
    }
    _navigationOngoing = false;
  }

  Future<void> _handleAction(BrowseAction action) async {
    switch (action.op) {
      case BrowseActionType.navigateTo:
        final NavigateToAction navigate = action;
        _navigationOngoing = true;
        await _addUrl(navigate.url, needsRedirect: true);
        await webView.controller.loadUrl(
            navigate.url, web.LoadUrlParams(type: web.LoadUrlReason.typed));
        break;
      case BrowseActionType.goBack:
        _navigateInHistory(delta: -1);
        _navigationOngoing = true;
        await webView.controller.goBack();
        break;
      case BrowseActionType.goForward:
        _navigateInHistory(delta: 1);
        _navigationOngoing = true;
        await webView.controller.goForward();
        break;
    }
  }

  void _navigateInHistory({@required delta}) {
    final state = _urlListHead;
    final newStateIndex = max(0, min(state + delta, _urlList.length - 1));
    final oldUrl = state == -1 ? null : _urlList[state],
        newUrl = _urlList[newStateIndex];
    _urlListHead = newStateIndex;
    _updateControllers();
    _notifyNavigationUpdate(oldUrl, newUrl);
  }

  Future<Null> _addUrl(String newUrl, {bool needsRedirect = false}) async {
    var url = newUrl;
    if (needsRedirect) {
      url = await _followRedirects(newUrl);
    }
    _urlList
      ..removeRange(_urlListHead + 1, _urlList.length)
      ..add(url);
    _navigateInHistory(delta: 1);
  }

  void _updateControllers() {
    _forwardController.add(_urlListHead < _urlList.length - 1);
    _backController.add(_urlListHead > 0);
  }

  void _notifyNavigationUpdate(String oldUrl, String newUrl) {
    _urlController.add(newUrl);
  }

  Future<String> _followRedirects(String url) async {
    final request = await HttpClient().getUrl(Uri.parse(url));
    request.followRedirects = true;
    final response = await request.close();
    final uri = response.redirects
        .map((r) => r.location)
        .toList()
        .reversed
        .firstWhere((url) => url.isAbsolute, orElse: () => null);
    return uri?.toString() ?? url;
  }

  void dispose() {
    _urlController.close();
    _browseActionController.close();
    _forwardController.close();
    _backController.close();
  }
}
