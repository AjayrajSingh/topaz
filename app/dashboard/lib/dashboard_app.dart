// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets.dart/model.dart';

import 'build_status_model.dart';
import 'build_status_widget.dart';
import 'info_text.dart';
import 'service/build_service.dart';

const Color _kFuchsiaColor = const Color(0xFFFF0080);

/// Callback to launch a module that displays the [url].
typedef OnLaunchUrl = void Function(String url);

/// Displays the fuchsia dashboard.
class DashboardApp extends StatelessWidget {
  /// Models for the build status widgets to display.
  final List<List<BuildStatusModel>> buildStatusModels;

  /// Called when the refresh FAB is pressed.
  final VoidCallback onRefresh;

  /// Called when a build status widget is pressed.
  final OnLaunchUrl onLaunchUrl;

  /// The service used to fetch build information.
  final BuildService buildService;

  final DateTime buildTimestamp;

  /// Constructor.
  const DashboardApp({
    this.buildService,
    this.buildStatusModels,
    this.buildTimestamp,
    this.onRefresh,
    this.onLaunchUrl,
  });

  @override
  Widget build(BuildContext context) => new LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) =>
            constraints.maxHeight == 0.0 || constraints.maxWidth == 0.0
                ? const Offstage()
                : _buildWidget(context),
      );

  Widget _buildWidget(BuildContext context) {
    List<Widget> rows = <Widget>[];

    // Get the max number of children a row can have.
    int maxRowChildren = 0;
    for (List<BuildStatusModel> models in buildStatusModels) {
      if (models.length > maxRowChildren) {
        maxRowChildren = models.length;
      }
    }

    for (List<BuildStatusModel> models in buildStatusModels) {
      List<Widget> rowChildren = models
          .map(
            (BuildStatusModel model) => new Expanded(
                  child: new ScopedModel<BuildStatusModel>(
                    model: model,
                    child: new BuildStatusWidget(
                      onTap: () => onLaunchUrl?.call(model.url),
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
          child: new Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.max,
            children: rowChildren,
          ),
        ),
      );
    }

    rows.add(
      new InfoText(
        buildTimestamp: buildTimestamp,
        timeoutRate: () => buildService.timeoutRate,
      ),
    );

    return new MaterialApp(
      title: 'Fuchsia Build Status',
      theme: new ThemeData(primaryColor: _kFuchsiaColor),
      home: new Container(
        color: Colors.grey[200],
        child: new Stack(children: <Widget>[
          new Column(children: rows),
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
                    onPressed: () => onRefresh?.call(),
                    tooltip: 'Refresh',
                    child: const Icon(Icons.refresh),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
