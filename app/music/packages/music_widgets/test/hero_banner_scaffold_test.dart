// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_widgets/music_widgets.dart';

void main() {
  testWidgets('Loading State', (WidgetTester tester) async {
    Key heroBannerKey = new UniqueKey();
    Key bodyKey = new UniqueKey();
    Key heroImageKey = new UniqueKey();
    await tester.pumpWidget(new Material(
      child: new HeroBannerScaffold(
        loadingStatus: LoadingStatus.inProgress,
        heroBanner: new Container(key: heroBannerKey),
        body: new Container(key: bodyKey),
        heroImage: new Container(key: heroImageKey),
      ),
    ));

    // Child widgets should not be in the widget tree
    expect(find.byKey(heroBannerKey), findsNothing);
    expect(find.byKey(bodyKey), findsNothing);
    expect(find.byKey(heroImageKey), findsNothing);
  });

  testWidgets('Failure State', (WidgetTester tester) async {
    Key heroBannerKey = new UniqueKey();
    Key bodyKey = new UniqueKey();
    Key heroImageKey = new UniqueKey();
    await tester.pumpWidget(new Material(
      child: new HeroBannerScaffold(
        loadingStatus: LoadingStatus.failed,
        heroBanner: new Container(key: heroBannerKey),
        body: new Container(key: bodyKey),
        heroImage: new Container(key: heroImageKey),
      ),
    ));

    // Child widgets should not be in the widget tree
    expect(find.byKey(heroBannerKey), findsNothing);
    expect(find.byKey(bodyKey), findsNothing);
    expect(find.byKey(heroImageKey), findsNothing);

    // Error message should show up
    expect(find.text('Content failed to load'), findsOneWidget);
  });

  testWidgets('Completed State', (WidgetTester tester) async {
    Key heroBannerKey = new UniqueKey();
    Key bodyKey = new UniqueKey();
    Key heroImageKey = new UniqueKey();
    await tester.pumpWidget(new Material(
      child: new HeroBannerScaffold(
        loadingStatus: LoadingStatus.completed,
        heroBanner: new Container(key: heroBannerKey),
        body: new Container(key: bodyKey),
        heroImage: new Container(key: heroImageKey),
      ),
    ));

    // Child widgets should be in the widget tree
    expect(find.byKey(heroBannerKey), findsOneWidget);
    expect(find.byKey(bodyKey), findsOneWidget);
    expect(find.byKey(heroImageKey), findsOneWidget);
  });
}
