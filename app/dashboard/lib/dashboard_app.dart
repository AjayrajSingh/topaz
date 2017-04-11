// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';

import 'build_status_model.dart';
import 'build_status_widget.dart';
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
      theme: new ThemeData(
        primaryColor: _kFuchsiaColor,
      ),
      home: new Scaffold(
        backgroundColor: Colors.grey[200],
        appBar: Platform.isFuchsia
            ? null
            : new AppBar(title: new Text('Fuchsia Build Status')),
        body: new Column(children: rows),
        floatingActionButton: new FloatingActionButton(
          backgroundColor: _kFuchsiaColor,
          onPressed: () => onRefresh?.call(),
          tooltip: 'Refresh',
          child: new Icon(Icons.refresh),
        ),
      ),
    );
  }
}
