// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dashboard/service/build_service.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';

import 'package:dashboard/build_status_model.dart';
import 'package:dashboard/build_status_widget.dart';
import 'package:dashboard/info_text.dart';

const double _kSpaceBetween = 4.0;

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

  /// Constructor.
  const DashboardApp({
    this.buildService,
    this.buildStatusModels,
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
    }

    rows.add(new InfoText(timeoutRate: () => buildService.timeoutRate));

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
                /*
                // TODO: Re-add this when we have a working chat app.
                // MS-1461
                new Padding(
                  padding: const EdgeInsets.only(
                    bottom: 16.0,
                    right: 16.0,
                  ),
                  child: new FloatingActionButton(
                    backgroundColor: _kFuchsiaColor,
                    onPressed: () =>
                        DashboardModuleModel.of(context).launchChat(),
                    tooltip: 'Chat',
                    child: new Icon(Icons.chat),
                  ),
                ),
                */
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
