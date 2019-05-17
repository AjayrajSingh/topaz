// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:fuchsia_inspect/inspect.dart' as inspect;

/// A Flutter app that demonstrates usage of the [Inspect] API.
class InspectExampleApp extends StatelessWidget {
  static const _appColor = Colors.blue;

  final inspect.Node _inspectNode;

  InspectExampleApp(this._inspectNode) {
    _initProperties();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inspect Example',
      theme: ThemeData(
        primarySwatch: _appColor,
      ),
      home: _InspectHomePage(
          title: 'Hello Inspect!',
          inspectNode: _inspectNode.child('home-page')),
    );
  }

  /// Initializes the [Inspect] properties for this widget.
  void _initProperties() {
    _inspectNode.stringProperty('app-color').setValue('$_appColor');
  }
}

class _InspectHomePage extends StatefulWidget {
  final String title;
  final inspect.Node inspectNode;

  _InspectHomePage({Key key, this.title, this.inspectNode}) : super(key: key) {
    inspectNode.stringProperty('title').setValue(title);
  }

  @override
  _InspectHomePageState createState() => _InspectHomePageState(inspectNode);
}

class _InspectHomePageState extends State<_InspectHomePage> {
  /// Possible background colors.
  static const _colors = [
    Colors.white,
    Colors.lime,
    Colors.orange,
  ];

  final inspect.Node _inspectNode;

  /// A property that tracks [_counter].
  final inspect.IntProperty _counterProperty;

  inspect.StringProperty _backgroundProperty;

  int _counter = 0;
  int _colorIndex = 0;

  _InspectHomePageState(this._inspectNode)
      : _counterProperty = _inspectNode.intProperty('counter') {
    _backgroundProperty = _inspectNode.stringProperty('background-color')
      ..setValue('$_backgroundColor');
  }

  Color get _backgroundColor => _colors[_colorIndex];

  void _incrementCounter() {
    setState(() {
      _counter++;

      // Note: an alternate approach that is also valid is to set the property
      // to the new value:
      //
      //     _counterProperty.setValue(_counter);
      _counterProperty.add(1);
    });
  }

  void _decrementCounter() {
    setState(() {
      _counter--;
      _counterProperty.subtract(1);
    });
  }

  /// Increments through the possible [_colors].
  ///
  /// If we've reached the end, start over at the beginning.
  void _changeBackground() {
    setState(() {
      _colorIndex++;

      if (_colorIndex >= _colors.length) {
        _colorIndex = 0;

        // Contrived example of removing an Inspect property:
        // Once we've looped through the colors once, delete the  to.
        //
        // A more realistic example would be if something were being removed
        // from the UI, but this is intended to be super simple.
        _backgroundProperty.delete();
        // Setting _backgroundProperty to null is optional; it's fine to
        // call setValue() on a deleted property - it will just have no effect.
        _backgroundProperty = null;
      }

      _backgroundProperty?.setValue('$_backgroundColor');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
        ),
      ),
      backgroundColor: _backgroundColor,
      body: Center(
        child: Text(
          'Counter: $_counter.',
        ),
      ),
      persistentFooterButtons: <Widget>[
        FlatButton(
          onPressed: _changeBackground,
          child: Text('Change background color'),
        ),
        FlatButton(
          onPressed: _incrementCounter,
          child: Text('Increment counter'),
        ),
        FlatButton(
          onPressed: _decrementCounter,
          child: Text('Decrement counter'),
        ),
      ],
    );
  }
}
