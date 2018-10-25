// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

void main() {
  // TODO(FL-154): ideally we wouldn't need to override FlutterError.onError
  // but right now only the unhandled Dart exceptions are actually caught in the
  // C++ runner so this makes sure that the Flutter errors, in addition to the
  // Dart errors, are caught in the runner.
  FlutterError.onError = (FlutterErrorDetails details) async {
    Zone.current.handleUncaughtError(details.exception, details.stack);
  };

  runApp(FlutterCrasherApp());
}

class FlutterCrasherApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlutterCrasher',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter crasher'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            RaisedButton(
              child: Text('Throw a Flutter error'),
              elevation: 1.0,
              onPressed: () {
                throw StateError(
                    'This would get caught by FlutterError.onError.');
              },
            ),
            RaisedButton(
              child: Text('Throw a Dart error'),
              elevation: 1.0,
              onPressed: () async {
                Future<void> foo() async {
                  throw StateError('This would get caught by Zone.onError.');
                }

                Future<void> bar() async {
                  await foo();
                }

                await bar();
              },
            ),
          ],
        ),
      ),
    );
  }
}
