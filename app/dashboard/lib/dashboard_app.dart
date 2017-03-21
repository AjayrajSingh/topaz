// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:core';
import 'dart:async';

enum _BuildStatus { unknown, networkError, parseError, success, failure }

// ----------------------------------------------------------------------------
// EDIT BELOW TO ADD configs

final String _kBaseURL = 'https://luci-scheduler.appspot.com/jobs/';

class _BuildInfo {
  _BuildStatus status = _BuildStatus.unknown;
  String url;

  _BuildInfo({this.status, this.url});
}

const Map<String, List<List<String>>> _kTargetsMap =
    const <String, List<List<String>>>{
  'fuchsia': const <List<String>>[
    const <String>['fuchsia/linux-x86-64-debug', 'linux-x86-64-debug'],
    const <String>['fuchsia/linux-arm64-debug', 'linux-arm64-debug'],
    const <String>['fuchsia/linux-x86-64-release', 'linux-x86-64-release'],
    const <String>['fuchsia/linux-arm64-release', 'linux-arm64-release'],
  ],
  'fuchsia-drivers': const <List<String>>[
    const <String>['fuchsia/drivers-linux-x86-64-debug', 'linux-x86-64-debug'],
    const <String>['fuchsia/drivers-linux-arm64-debug', 'linux-arm64-debug'],
    const <String>[
      'fuchsia/drivers-linux-x86-64-release',
      'linux-x86-64-release'
    ],
    const <String>[
      'fuchsia/drivers-linux-arm64-release',
      'linux-arm64-release'
    ],
  ],
  'magenta': const <List<String>>[
    const <String>['magenta/arm64-linux-gcc', 'arm64-linux-gcc'],
    const <String>['magenta/x86-64-linux-gcc', 'x86-64-linux-gcc'],
    const <String>['magenta/arm64-linux-clang', 'arm64-linux-clang'],
    const <String>['magenta/x86-64-linux-clang', 'x86-64-linux-clang'],
  ],
  'jiri': const <List<String>>[
    const <String>['jiri/linux-x86-64', 'linux-x86-64'],
    const <String>['jiri/mac-x86-64', 'mac-x86-64'],
  ]
};

/// Displays the fuchsia dashboard.
class DashboardApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Fuchsia Build Status',
      theme: new ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: new _DashboardPage(title: 'Fuchsia Build Status'),
    );
  }
}

class _DashboardPage extends StatefulWidget {
  _DashboardPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _DashboardPageState createState() => new _DashboardPageState();
}

class _DashboardPageState extends State<_DashboardPage> {
  Map<String, Map<String, _BuildInfo>> _targetsResults;
  DateTime _startTime = new DateTime.now();

  @override
  void initState() {
    super.initState();
    // From the targets map, create a data structure which we'll be populating
    // the build results into, as they come in async.
    _targetsResults = new Map<String, Map<String, _BuildInfo>>();

    _kTargetsMap
        .forEach((String categoryName, List<List<String>> buildConfigs) {
      Map<String, _BuildInfo> map = new Map<String, _BuildInfo>();
      buildConfigs.forEach((List<String> config) {
        map[config[1]] = new _BuildInfo(
          status: _BuildStatus.unknown,
          url: 'http://www.google.com',
        );
      });
      _targetsResults[categoryName] = map;
    });

    new Timer.periodic(
      const Duration(seconds: 60),
      _refreshTimerFired,
    );
    _refreshStatus();
  }

  void _refreshTimerFired(Timer t) => _refreshStatus();

  // Refresh status an ALL builds.
  void _refreshStatus() {
    // fetch config status for ONE item.
    Future<Null> _fetchConfigStatus(
      String categoryName,
      String buildName,
      String url,
    ) async {
      _BuildStatus status = _BuildStatus.parseError;
      String html;

      try {
        http.Response response = await http.get(url);
        html = response.body;
      } catch (error) {
        status = _BuildStatus.networkError;
      }

      if (html == null) {
        status = _BuildStatus.networkError;
      } else {
        dom.Document domTree = parse(html);
        List<dom.Element> trs = domTree.querySelectorAll('tr');
        for (dom.Element tr in trs) {
          if (tr.className == "danger") {
            status = _BuildStatus.failure;
            break;
          } else if (tr.className == "success") {
            status = _BuildStatus.success;
            break;
          }
        }
      }

      _targetsResults['$categoryName']['$buildName'].status = status;
      _targetsResults['$categoryName']['$buildName'].url = url;
      setState(() {});
    } // _fetchConfigStatus

    // kick off requests for all the build configs desired. As
    // these reults come in they will be stuffed into the targets_results map.
    _kTargetsMap
        .forEach((String categoryName, List<List<String>> buildConfigs) {
      buildConfigs.forEach((List<String> config) {
        String url = _kBaseURL + config[0];
        _fetchConfigStatus(categoryName, config[1], url);
      });
    }); // targets_forEach
  } // _refreshStatus

  void _launchUrl(String url) {
    UrlLauncher.launch(url);
  }

  Color _colorFromBuildStatus(_BuildStatus status) {
    switch (status) {
      case _BuildStatus.success:
        return Colors.green[300];
      case _BuildStatus.failure:
        return Colors.red[400];
      case _BuildStatus.networkError:
        return Colors.purple[100];
      default:
        return Colors.black12;
    }
  }

  Widget _buildResultWidget(String type, String name, _BuildInfo bi) =>
      new Expanded(
        child: new GestureDetector(
          onTap: () {
            _launchUrl(bi.url);
          },
          child: new Container(
            color: _colorFromBuildStatus(bi.status),
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            margin: const EdgeInsets.only(right: 8.0, bottom: 8.0),
            child: new Center(
              child: new Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  new Text(
                    type,
                    textAlign: TextAlign.center,
                    style: new TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w300,
                      fontSize: 14.0,
                    ),
                  ),
                  new Container(height: 4.0),
                  new Text(
                    name,
                    textAlign: TextAlign.center,
                    style: new TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                      fontSize: 14.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    List<Widget> rows = <Widget>[];

    Duration uptime = new DateTime.now().difference(_startTime);

    rows.add(
      new Container(
        height: 32.0,
        child: new Center(
          child: new Text(
            "${uptime.inDays}d ${uptime.inHours % 24}h ${uptime.inMinutes % 60}m",
            textAlign: TextAlign.center,
            style: new TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );

    _targetsResults.forEach((String k, Map<String, _BuildInfo> v) {
      // the builds
      List<Widget> builds = <Widget>[];
      v.forEach((String name, _BuildInfo statusObj) {
        builds.add(_buildResultWidget(k, name, statusObj));
      });

      rows.add(
        new Expanded(
          child: new Container(
            margin: const EdgeInsets.only(left: 8.0),
            child: new Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.max,
              children: builds,
            ),
          ),
        ),
      );
    });

    return new Scaffold(
      appBar: Platform.isFuchsia
          ? null
          : new AppBar(title: new Text('Fuchsia Build Status')),
      body: new Column(children: rows),
      floatingActionButton: new FloatingActionButton(
        onPressed: _refreshStatus,
        tooltip: 'Increment',
        child: new Icon(Icons.refresh),
      ),
    );
  }
}
