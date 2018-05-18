// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:dashboard/enums.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/widgets.dart';

import 'package:dashboard/build_status_model.dart';
import 'package:dashboard/info_text.dart' show toConciseString;

/// Displays a build status using its ancestor [BuildStatusModel].
class BuildStatusWidget extends StatefulWidget {
  /// Called then the widget is tapped.
  final VoidCallback onTap;

  /// Constructor.
  const BuildStatusWidget({this.onTap});

  @override
  _BuildStatusWidgetState createState() => new _BuildStatusWidgetState();
}

class _BuildStatusWidgetState extends State<BuildStatusWidget> {
  Timer _timer;
  Size _size;

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
  Widget build(BuildContext context) => new LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
        _size = constraints.biggest;
        return new ScopedModelDescendant<BuildStatusModel>(
          builder:
              (BuildContext context, Widget child, BuildStatusModel model) {
            Color backgroundColor = _colorFromBuildStatus(model);
            bool hasError = model.errorMessage?.isNotEmpty ?? false;
            List<Widget> columnChildren = <Widget>[
              new Text(
                model.type,
                textAlign: TextAlign.center,
                style: hasError
                    ? _getUnimportantStyle(backgroundColor)
                        .copyWith(fontSize: _errorFontSize)
                    : _getUnimportantStyle(backgroundColor),
              ),
              new Container(height: 4.0),
              new Text(
                model.name,
                textAlign: TextAlign.center,
                style: hasError
                    ? _getImportantStyle(backgroundColor)
                        .copyWith(fontSize: _errorFontSize)
                    : _getImportantStyle(backgroundColor),
              ),
            ];
            if (hasError) {
              columnChildren.addAll(<Widget>[
                new Container(height: 4.0),
                new Text(
                  model.errorMessage,
                  textAlign: TextAlign.left,
                  style: _errorStyle,
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
                    child: const FuchsiaSpinner(),
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
                      style: _getTimerStyle(backgroundColor),
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
                      style: _getTimerStyle(backgroundColor),
                    ),
                  ),
                ),
              );
            }

            stackChildren.add(
              new Align(
                alignment: FractionalOffset.topLeft,
                child: new Container(
                  margin: const EdgeInsets.only(top: 8.0),
                  child: new Text(
                    _statusTextFromBuildStatus(model),
                    style: _getStatusStyle(backgroundColor),
                  ),
                ),
              ),
            );

            return new Material(
              elevation: 2.0,
              color: backgroundColor,
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
      });

  Color _colorFromBuildStatus(BuildStatusModel model) {
    if (model.buildResult == BuildResultEnum.success) {
      return model.successColor;
    } else if (model.buildResult == BuildResultEnum.failure) {
      return model.failColor;
    } else {
      return Colors.grey[300];
    }
  }

  String _statusTextFromBuildStatus(BuildStatusModel model) {
    if (model.buildResult == BuildResultEnum.success) {
      return 'passing 🙆';
    } else if (model.buildResult == BuildResultEnum.failure) {
      return 'failing 🙅';
    } else {
      return 'unknown 🤷';
    }
  }

  Color _getTextColor(Color backgroundColor) {
    // See http://www.w3.org/TR/AERT#color-contrast for the details of this
    // algorithm.
    int brightness = (((backgroundColor.red * 299) +
                (backgroundColor.green * 587) +
                (backgroundColor.blue * 114)) /
            1000)
        .round();

    return (brightness > 125) ? Colors.black : Colors.white;
  }

  double get _fontSize => _size.height / 6.0;
  double get _timerFontSize => _size.height / 10.0;
  double get _errorFontSize => _size.height / 10.0;
  double get _statusFontSize => _timerFontSize;
  TextStyle _getImportantStyle(Color backgroundColor) => new TextStyle(
        color: _getTextColor(backgroundColor),
        fontSize: _fontSize,
        fontWeight: FontWeight.w500,
      );

  TextStyle _getUnimportantStyle(Color backgroundColor) =>
      _getImportantStyle(backgroundColor).copyWith(
        fontWeight: FontWeight.w300,
      );

  TextStyle _getTimerStyle(Color backgroundColor) =>
      _getImportantStyle(backgroundColor).copyWith(
        fontSize: _timerFontSize,
      );

  TextStyle get _errorStyle => new TextStyle(
        color: Colors.red[900],
        fontWeight: FontWeight.w900,
        fontSize: _errorFontSize,
      );

  TextStyle _getStatusStyle(Color backgroundColor) =>
      _getImportantStyle(backgroundColor).copyWith(
        fontSize: _statusFontSize,
      );
}
