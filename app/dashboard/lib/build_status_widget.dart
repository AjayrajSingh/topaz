// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

enum BuildStatus { unknown, networkError, parseError, success, failure }

const double _kFontSize = 20.0;
const double _kErrorFontSize = 12.0;
const double _kSpaceBetween = 4.0;

final TextStyle _kImportantStyle = new TextStyle(
  color: Colors.black,
  fontSize: _kFontSize,
  fontWeight: FontWeight.w500,
);

final TextStyle _kUnimportantStyle = _kImportantStyle.copyWith(
  fontWeight: FontWeight.w300,
);

const Color _kFuchsiaColor = const Color(0xFFFF0080);

class BuildInfo {
  BuildStatus status = BuildStatus.unknown;
  String url;
  String errorMessage;
  DateTime lastRefreshStarted;
  DateTime lastRefreshEnded;

  BuildInfo({this.status, this.url, this.errorMessage});
}

class BuildStatusWidget extends StatelessWidget {
  final String type;
  final String name;
  final BuildInfo bi;
  final VoidCallback onTap;

  BuildStatusWidget({this.type, this.name, this.bi, this.onTap});

  Color _colorFromBuildStatus(BuildStatus status) {
    switch (status) {
      case BuildStatus.success:
        return Colors.green[300];
      case BuildStatus.failure:
        return Colors.red[400];
      case BuildStatus.networkError:
        return Colors.purple[100];
      default:
        return Colors.grey[300];
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasError = bi.errorMessage?.isNotEmpty ?? false;
    List<Widget> columnChildren = <Widget>[
      new Text(
        type,
        textAlign: TextAlign.center,
        style: hasError
            ? _kUnimportantStyle.copyWith(fontSize: _kErrorFontSize)
            : _kUnimportantStyle,
      ),
      new Container(height: 4.0),
      new Text(
        name,
        textAlign: TextAlign.center,
        style: hasError
            ? _kImportantStyle.copyWith(fontSize: _kErrorFontSize)
            : _kImportantStyle,
      ),
    ];
    if (hasError) {
      columnChildren.addAll(<Widget>[
        new Container(height: 4.0),
        new Text(
          bi.errorMessage,
          textAlign: TextAlign.left,
          style: new TextStyle(
            color: Colors.red[900],
            fontWeight: FontWeight.w900,
            fontSize: _kErrorFontSize,
          ),
        ),
      ]);
    }

    List<Widget> stackChildren = <Widget>[
      new Center(
        child: new Column(
          mainAxisSize: MainAxisSize.min,
          children: columnChildren,
        ),
      ),
    ];

    if (bi.lastRefreshEnded == null) {
      stackChildren.add(
        new Align(
          alignment: FractionalOffset.bottomCenter,
          child: new Container(
            margin: const EdgeInsets.only(bottom: 8.0),
            width: 16.0,
            height: 16.0,
            child: new CircularProgressIndicator(
              valueColor: new AlwaysStoppedAnimation<Color>(_kFuchsiaColor),
            ),
          ),
        ),
      );
    } else {
      stackChildren.add(
        new Align(
          alignment: FractionalOffset.bottomCenter,
          child: new Container(
            margin: const EdgeInsets.only(bottom: 8.0, right: 8.0),
            child: new Text(
              '${bi.lastRefreshEnded.difference(bi.lastRefreshStarted).inMilliseconds} ms',
              style: new TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w100,
                fontSize: _kErrorFontSize,
              ),
            ),
          ),
        ),
      );
    }

    return new GestureDetector(
      onTap: onTap,
      child: new Container(
        decoration: new BoxDecoration(
          backgroundColor: _colorFromBuildStatus(bi.status),
          borderRadius: new BorderRadius.circular(8.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: new Stack(children: stackChildren),
      ),
    );
  }
}
