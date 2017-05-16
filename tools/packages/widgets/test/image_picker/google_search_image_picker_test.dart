// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:search_api/search_api.dart';
import 'package:widgets/image_picker.dart';

/// Mock Search API returns hardcoded images
class MockSearchAPI extends SearchAPI {
  @override
  Future<List<String>> images({
    String query,
  }) async {
    return _images;
  }
}

final List<String> _images = <String>[
  'https://github.com/dvdwasibi/DogsOfFuchsia/blob/master/coco.jpg?raw=true&i=1',
  'https://github.com/dvdwasibi/DogsOfFuchsia/blob/master/coco.jpg?raw=true&i=2',
  'https://github.com/dvdwasibi/DogsOfFuchsia/blob/master/coco.jpg?raw=true&i=3',
  'https://github.com/dvdwasibi/DogsOfFuchsia/blob/master/coco.jpg?raw=true&i=4',
];

void main() {
  final String _query = 'bunnies';
  List<String> _selectedImages = <String>[];
  List<String> _imagesToAdd = <String>[];

  GoogleSearchImagePicker _createGoogleSearchImagePicker() {
    _selectedImages = <String>[];
    _imagesToAdd = <String>[];

    return new GoogleSearchImagePicker(
      searchApi: new MockSearchAPI(),
      initialQuery: _query,
      initialSelection: null,
      onSelectionChanged: (List<String> selectedImages) {
        _selectedImages = selectedImages;
      },
      onAdd: (List<String> selectedImages) {
        _imagesToAdd = selectedImages;
      },
    );
  }

  Future<Null> _pumpAnimations(WidgetTester tester) async {
    // We could've used pumpAndSettle() but we have a loading indicator
    // The first pump starts pumping of overlay animation, second one
    // pumps to end of overlay anmiation.
    await tester.pump();
    await tester.pump(new Duration(milliseconds: 1000));
  }

  testWidgets(
    'The search query should exist when images are loaded, and '
        'clear when the user clicks the clear (x) icon',
    (WidgetTester tester) async {
      await tester.pumpWidget(new Material(
        child: _createGoogleSearchImagePicker(),
      ));
      // rebuild imagePicker with new _sourceImages and _lastSearchQuery
      await tester.pump();

      Finder searchBar =
          find.byWidgetPredicate((Widget widget) => widget is TextField);
      expect(searchBar, findsOneWidget);
      TextField searchField = tester.widget(searchBar);
      expect(searchField.controller.text, _query);

      Finder clearIconButton = find.byWidgetPredicate((Widget widget) {
        if (widget is IconButton && widget.icon is Icon) {
          Icon icon = widget.icon;
          return icon.icon == Icons.clear;
        }
        return false;
      });
      await tester.tap(clearIconButton);
      await _pumpAnimations(tester);
      searchField = tester.widget(searchBar);
      expect(searchField.controller.text, '');
    },
  );

  testWidgets(
    'The "x images selected" overlay should not appear when no images are selected',
    (WidgetTester tester) async {
      await tester.pumpWidget(new Material(
        child: _createGoogleSearchImagePicker(),
      ));
      await tester.pump(); // rebuild imagePicker with new _sourceImages

      expect(find.text('1 image selected'), findsNothing);
    },
  );

  testWidgets(
    'Tapping on an ImageEntry should set it as SELECTED and the '
        ' "x images selected" overlay should appear when at least '
        ' one image is selected. Tapping on a selected image should unselect it',
    (WidgetTester tester) async {
      await tester.pumpWidget(new Material(
        child: _createGoogleSearchImagePicker(),
      ));
      await tester.pump(); // rebuild imagePicker with new _sourceImages

      Finder firstImage = find.byWidgetPredicate((Widget widget) =>
          widget is ImageEntry && widget.imageUrl == _images.first);
      await tester.tap(firstImage);
      await tester.pump(); // image UI change + "x images selected" overlay

      ImageEntry image = tester.widget(firstImage);
      expect(image.selected, true);
      expect(_selectedImages.length, 1);
      Finder text = find.text('1 image selected');
      expect(text, findsOneWidget);

      await tester.tap(firstImage);
      await tester.pump();
      image = tester.widget(firstImage);
      expect(image.selected, false);
      expect(_selectedImages.length, 0);
      expect(text, findsNothing);
    },
  );

  testWidgets(
    'Tapping on the check icon ("add" button) should call the onAdd callback'
        ' with all the selected images',
    (WidgetTester tester) async {
      await tester.pumpWidget(new Material(
        child: _createGoogleSearchImagePicker(),
      ));
      await tester.pump(); // rebuild imagePicker with new _sourceImages

      Finder firstImage = find.byWidgetPredicate((Widget widget) =>
          widget is ImageEntry && widget.imageUrl == _images.first);
      Finder secondImage = find.byWidgetPredicate((Widget widget) =>
          widget is ImageEntry && widget.imageUrl == _images[1]);
      await tester.tap(firstImage);
      await tester.tap(secondImage);
      await _pumpAnimations(tester);

      Finder checkIconButton = find.byWidgetPredicate((Widget widget) {
        if (widget is IconButton && widget.icon is Icon) {
          Icon icon = widget.icon;
          return (icon.icon == Icons.check && widget.color != Colors.white);
        }
        return false;
      });
      await tester.tap(checkIconButton);
      await tester.pump();
      expect(_imagesToAdd.length, 2);
      expect(_imagesToAdd.contains(_images[0]), true);
      expect(_imagesToAdd.contains(_images[1]), true);
    },
  );

  testWidgets(
    'Tapping on the clear icon ("cancel" button) should unselect all images',
    (WidgetTester tester) async {
      await tester.pumpWidget(new Material(
        child: _createGoogleSearchImagePicker(),
      ));
      await tester.pump(); // rebuild imagePicker with new _sourceImages

      Finder firstImage = find.byWidgetPredicate((Widget widget) =>
          widget is ImageEntry && widget.imageUrl == _images.first);
      Finder secondImage = find.byWidgetPredicate((Widget widget) =>
          widget is ImageEntry && widget.imageUrl == _images[1]);
      await tester.tap(firstImage);
      await tester.tap(secondImage);
      await _pumpAnimations(tester);

      // Two images are selected, each with a check icon + overlay's check icon
      Finder checkIcons = find.byIcon(Icons.check);
      expect(checkIcons, findsNWidgets(3));
      Finder text = find.text('2 images selected');
      expect(text, findsOneWidget);

      // There should be no more selected images, and no more overlay
      // after tapping clear icon
      Finder clearIconButton = find.byWidgetPredicate((Widget widget) {
        if (widget is IconButton && widget.icon is Icon) {
          Icon icon = widget.icon;
          return icon.icon == Icons.clear;
        }
        return false;
      }).first;
      await tester.tap(clearIconButton);
      await _pumpAnimations(tester);
      checkIcons = find.byIcon(Icons.check);
      expect(checkIcons, findsNothing);
    },
  );
}
