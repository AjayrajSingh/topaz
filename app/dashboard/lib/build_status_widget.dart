// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';

import 'build_status_model.dart';
import 'info_text.dart' show toConciseString;

const double _kFontSize = 20.0;
const double _kTimerFontSize = 12.0;
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

final TextStyle _kTimerStyle = _kImportantStyle.copyWith(
  fontSize: _kTimerFontSize,
);

final TextStyle _kErrorStyle = new TextStyle(
  color: Colors.red[900],
  fontWeight: FontWeight.w900,
  fontSize: _kErrorFontSize,
);

final TextStyle _kRefreshDurationStyle = new TextStyle(
  color: Colors.black,
  fontWeight: FontWeight.w100,
  fontSize: _kErrorFontSize,
);

const Color _kFuchsiaColor = const Color(0xFFFF0080);

/// Displays a build status using its ancestor [BuildStatusModel].
class BuildStatusWidget extends StatefulWidget {
  /// Called then the widget is tapped.
  final VoidCallback onTap;

  /// Constructor.
  BuildStatusWidget({this.onTap});

  @override
  _BuildStatusWidgetState createState() => new _BuildStatusWidgetState();
}

class _BuildStatusWidgetState extends State<BuildStatusWidget> {
  Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = new Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
    _timer = null;
  }

  @override
  Widget build(BuildContext context) =>
      new ScopedModelDescendant<BuildStatusModel>(
        builder: (BuildContext context, Widget child, BuildStatusModel model) {
          bool hasError = model.errorMessage?.isNotEmpty ?? false;
          List<Widget> columnChildren = <Widget>[
            new Text(
              model.type,
              textAlign: TextAlign.center,
              style: hasError
                  ? _kUnimportantStyle.copyWith(fontSize: _kErrorFontSize)
                  : _kUnimportantStyle,
            ),
            new Container(height: 4.0),
            new Text(
              model.name,
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
                model.errorMessage,
                textAlign: TextAlign.left,
                style: _kErrorStyle,
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

          if (model.lastRefreshEnded == null) {
            stackChildren.add(
              new Align(
                alignment: FractionalOffset.bottomCenter,
                child: new Container(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  width: 16.0,
                  height: 16.0,
                  child: new CircularProgressIndicator(
                    valueColor:
                        new AlwaysStoppedAnimation<Color>(_kFuchsiaColor),
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
                    '${model.lastRefreshEnded.difference(model.lastRefreshStarted).inMilliseconds} ms',
                    style: _kRefreshDurationStyle,
                  ),
                ),
              ),
            );
          }

          if (model.lastFailTime != null) {
            Duration lastFailureTime =
                new DateTime.now().difference(model.lastFailTime);
            stackChildren.add(
              new Align(
                alignment: FractionalOffset.topRight,
                child: new Container(
                  margin: const EdgeInsets.only(top: 8.0),
                  child: new Text(
                    toConciseString(lastFailureTime),
                    style: _kTimerStyle,
                  ),
                ),
              ),
            );
          } else if (model.lastPassTime != null) {
            Duration lastPassTime = new DateTime.now().difference(
              model.lastPassTime,
            );
            stackChildren.add(
              new Align(
                alignment: FractionalOffset.topRight,
                child: new Container(
                  margin: const EdgeInsets.only(top: 8.0),
                  child: new Text(
                    toConciseString(lastPassTime),
                    style: _kTimerStyle,
                  ),
                ),
              ),
            );
          }

          return new Material(
            elevation: 2,
            color: _colorFromBuildStatus(model.buildStatus),
            borderRadius: new BorderRadius.circular(8.0),
            child: new InkWell(
              onTap: () => widget.onTap?.call(),
              child: new Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: new Stack(
                  fit: StackFit.passthrough,
                  children: stackChildren,
                ),
              ),
            ),
          );
        },
      );

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
}
