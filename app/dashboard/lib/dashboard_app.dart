// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show lerpDouble;

import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';

import 'build_status_model.dart';
import 'build_status_widget.dart';
import 'dashboard_module_model.dart';
import 'info_text.dart';

const double _kSpaceBetween = 4.0;

const Color _kFuchsiaColor = const Color(0xFFFF0080);

/// Callback to launch a module that displays the [url].
typedef void OnLaunchUrl(String url);

/// Displays the fuchsia dashboard.
class DashboardApp extends StatelessWidget {
  /// Models for the build status widgets to display.
  final List<List<BuildStatusModel>> buildStatusModels;

  /// Called when the refresh FAB is pressed.
  final VoidCallback onRefresh;

  /// Called when a build status widget is pressed.
  final OnLaunchUrl onLaunchUrl;

  /// Constructor.
  DashboardApp({this.buildStatusModels, this.onRefresh, this.onLaunchUrl});

  @override
  Widget build(BuildContext context) {
    List<Widget> rows = <Widget>[];

    // Get the max number of children a row can have.
    int maxRowChildren = 0;
    buildStatusModels.forEach((List<BuildStatusModel> models) {
      if (models.length > maxRowChildren) {
        maxRowChildren = models.length;
      }
    });

    buildStatusModels.forEach((List<BuildStatusModel> models) {
      List<Widget> rowChildren = models
          .map(
            (BuildStatusModel model) => new Expanded(
                  child: new Container(
                    margin: const EdgeInsets.only(
                      right: _kSpaceBetween,
                      top: _kSpaceBetween,
                    ),
                    child: new ScopedModel<BuildStatusModel>(
                      model: model,
                      child: new BuildStatusWidget(
                        onTap: () => onLaunchUrl?.call(model.url),
                      ),
                    ),
                  ),
                ),
          )
          .toList();

      // Add fillers for rows that don't have as many children as the max.
      bool addToEnd = true;
      while (rowChildren.length < maxRowChildren) {
        if (addToEnd) {
          rowChildren.add(new Expanded(child: new Container()));
        } else {
          rowChildren.insert(0, new Expanded(child: new Container()));
        }
        addToEnd = !addToEnd;
      }

      rows.add(
        new Expanded(
          child: new Container(
            margin: const EdgeInsets.only(left: _kSpaceBetween),
            child: new Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.max,
              children: rowChildren,
            ),
          ),
        ),
      );
    });

    rows.add(new InfoText());

    return new MaterialApp(
      title: 'Fuchsia Build Status',
      theme: new ThemeData(primaryColor: _kFuchsiaColor),
      home: new Container(
        color: Colors.grey[200],
        child: new LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            double chatWidth = constraints.maxWidth / 5.0;
            return new ScopedModelDescendant<DashboardModuleModel>(
              builder: (
                _,
                Widget child,
                DashboardModuleModel model,
              ) =>
                  new AnimatedBuilder(
                    animation: model.animation,
                    builder: (_, __) => new Stack(
                          children: <Widget>[
                            new Positioned.fill(
                              right: lerpDouble(
                                0.0,
                                chatWidth,
                                model.animation.value,
                              ),
                              child: new Stack(children: <Widget>[
                                child,
                                new Align(
                                  alignment: FractionalOffset.bottomRight,
                                  child: new Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      new Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 16.0,
                                          right: 16.0,
                                        ),
                                        child: new FloatingActionButton(
                                          backgroundColor: _kFuchsiaColor,
                                          onPressed: () => model.toggleChat(),
                                          tooltip: 'Chat',
                                          child: new Icon(Icons.chat),
                                        ),
                                      ),
                                      new Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 16.0,
                                          right: 16.0,
                                        ),
                                        child: new FloatingActionButton(
                                          backgroundColor: _kFuchsiaColor,
                                          onPressed: () => onRefresh?.call(),
                                          tooltip: 'Refresh',
                                          child: new Icon(Icons.refresh),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ]),
                            ),
                            new Positioned(
                              top: 0.0,
                              bottom: 0.0,
                              right: lerpDouble(
                                -chatWidth,
                                0.0,
                                model.animation.value,
                              ),
                              width: chatWidth,
                              child: new ChildView(
                                connection: model.chatChildViewConnection,
                              ),
                            ),
                          ],
                        ),
                  ),
              child: new Column(children: rows),
            );
          },
        ),
      ),
    );
  }
}
