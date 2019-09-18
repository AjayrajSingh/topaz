// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show utf8;

import 'package:fidl_fuchsia_net_http/fidl_async.dart' as fidl_net;
import 'package:fidl_fuchsia_web/fidl_async.dart' as fidl_web;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuchsia_webview_flutter/src/fuchsia_web_services.dart';
import 'package:fuchsia_webview_flutter/src/fuchsia_webview_platform_controller.dart';
import 'package:fuchsia_webview_flutter/webview.dart';
import 'package:mockito/mockito.dart';
import 'package:webview_flutter/platform_interface.dart';
import 'package:webview_flutter/webview_flutter.dart';

// ignore_for_file: implementation_imports

class MockFuchsiaWebServices extends Mock implements FuchsiaWebServices {}

class MockWebViewPlatformCallbacksHandler extends Mock
    implements WebViewPlatformCallbacksHandler {}

class MockFuchsiaWebViewPlatformController extends Mock
    implements FuchsiaWebViewPlatformController {}

class MockNavigationControllerProxy extends Mock
    implements fidl_web.NavigationControllerProxy {}

void main() {
  FuchsiaWebServices mockWebServices;
  fidl_web.NavigationControllerProxy mockNavigationController;

  setUp(() {
    mockWebServices = MockFuchsiaWebServices();
    mockNavigationController = MockNavigationControllerProxy();
    when(mockWebServices.navigationController)
        .thenReturn(mockNavigationController);
    WebView.platform = FuchsiaWebView(fuchsiaWebServices: mockWebServices);
  });

  tearDown(() {
    WebView.platform = null;
  });

  testWidgets('Create WebView', (WidgetTester tester) async {
    await tester.pumpWidget(const WebView());
  });

  group('navigation: ', () {
    WebViewController webViewController;
    WebView webView;

    setUp(() {
      webView = WebView(
        onWebViewCreated: (WebViewController webViewCtl) {
          webViewController = webViewCtl;
        },
      );
    });

    testWidgets('loadUrl', (WidgetTester tester) async {
      await tester.pumpWidget(webView);

      final headers = <String, String>{'header': 'value'};
      String url = 'https://google.com';
      await webViewController.loadUrl(url, headers: headers);

      verify(mockNavigationController.loadUrl(
          url,
          fidl_web.LoadUrlParams(
            type: fidl_web.LoadUrlReason.typed,
            headers: [
              fidl_net.Header(
                  name: utf8.encode('header'), value: utf8.encode('value'))
            ],
          )));
    });

    testWidgets('currentUrl', (WidgetTester tester) async {
      await tester.pumpWidget(webView);

      const fooUrl = 'www.foo.com';
      when(mockNavigationController.getVisibleEntry()).thenAnswer(
          (_) => (Future.value(fidl_web.NavigationState(url: fooUrl))));

      final resUrl = await webViewController.currentUrl();

      verify(mockNavigationController.getVisibleEntry());
      expect(resUrl, 'www.foo.com');
    });

    testWidgets('canGoBack', (WidgetTester tester) async {
      await tester.pumpWidget(webView);

      when(mockNavigationController.getVisibleEntry()).thenAnswer(
          (_) => (Future.value(fidl_web.NavigationState(canGoBack: true))));

      final canGoBack = await webViewController.canGoBack();

      verify(mockNavigationController.getVisibleEntry());
      expect(canGoBack, true);
    });

    testWidgets('canGoForward', (WidgetTester tester) async {
      await tester.pumpWidget(webView);

      when(mockNavigationController.getVisibleEntry()).thenAnswer(
          (_) => (Future.value(fidl_web.NavigationState(canGoForward: true))));

      final canGoForward = await webViewController.canGoForward();

      verify(mockNavigationController.getVisibleEntry());
      expect(canGoForward, true);
    });

    testWidgets('goBack', (WidgetTester tester) async {
      await tester.pumpWidget(webView);

      await webViewController.goBack();
      verify(mockNavigationController.goBack());
    });

    testWidgets('goForward', (WidgetTester tester) async {
      await tester.pumpWidget(webView);

      await webViewController.goForward();
      verify(mockNavigationController.goForward());
    });

    testWidgets('reload', (WidgetTester tester) async {
      await tester.pumpWidget(webView);

      await webViewController.reload();
      verify(mockNavigationController.reload(fidl_web.ReloadType.partialCache));
    });

    testWidgets('disposed when removed from widget tree',
        (WidgetTester tester) async {
      final includeWebview = ValueNotifier<bool>(true);
      await tester.pumpWidget(ValueListenableBuilder(
          valueListenable: includeWebview,
          builder: (_, includeWebviewValue, __) {
            return includeWebviewValue ? webView : Container();
          }));
      await tester.pumpAndSettle();

      verifyNever(mockWebServices.dispose());

      includeWebview.value = false;
      await tester.pumpAndSettle();

      verify(mockWebServices.dispose());
    });
  });

  group('JS injection', () {
    WebViewController webViewController;
    WebView webView;

    setUp(() {
      webView = WebView(
        onWebViewCreated: (WebViewController webViewCtl) {
          webViewController = webViewCtl;
        },
        javascriptMode: JavascriptMode.unrestricted,
      );
    });

    testWidgets('evaluateJavascript', (WidgetTester tester) async {
      await tester.pumpWidget(webView);
      const script = 'console.log("hello");';
      await webViewController.evaluateJavascript(script);
      verify(mockWebServices.evaluateJavascript(['*'], script));
    });
  });
}
