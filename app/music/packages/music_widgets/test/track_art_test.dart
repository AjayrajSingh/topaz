// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_widgets/music_widgets.dart';

void main() {
  testWidgets(
      'Default size should be 48dp and icon size should be half of total size',
      (WidgetTester tester) async {
    Key key = new UniqueKey();
    await tester.pumpWidget(new Material(
      child: new Center(
        child: new TrackArt(key: key),
      ),
    ));

    RenderBox box = tester.renderObject(find.byKey(key));
    expect(box.size, new Size.square(48.0));

    Icon icon = tester.widget(find.byWidgetPredicate(
        (Widget widget) => widget is Icon && widget.icon == Icons.music_note));
    expect(icon.size, 24.0);
  });

  testWidgets('Size argument', (WidgetTester tester) async {
    double size = 100.0;
    Key key = new UniqueKey();
    await tester.pumpWidget(new Material(
      child: new Center(
        child: new TrackArt(
          key: key,
          size: size,
        ),
      ),
    ));

    RenderBox box = tester.renderObject(find.byKey(key));
    expect(box.size, new Size.square(size));

    Icon icon = tester.widget(find.byWidgetPredicate(
        (Widget widget) => widget is Icon && widget.icon == Icons.music_note));
    expect(icon.size, size / 2.0);
  });
}
