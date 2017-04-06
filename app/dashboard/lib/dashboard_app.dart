// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;

import 'build_status_widget.dart';
import 'info_text.dart';

const double _kSpaceBetween = 4.0;

const String _kBaseURL = 'https://luci-scheduler.appspot.com/jobs/';
const Color _kFuchsiaColor = const Color(0xFFFF0080);

const Map<String, List<List<String>>> _kTargetsMap =
    const <String, List<List<String>>>{
  'fuchsia': const <List<String>>[
    const <String>['manifest/linux-x86-64-debug', 'linux-x86-64-debug'],
    const <String>['manifest/linux-arm64-debug', 'linux-arm64-debug'],
    const <String>['manifest/linux-x86-64-release', 'linux-x86-64-release'],
    const <String>['manifest/linux-arm64-release', 'linux-arm64-release'],
  ],
  'fuchsia-drivers': const <List<String>>[
    const <String>['manifest/drivers-linux-x86-64-debug', 'linux-x86-64-debug'],
    const <String>['manifest/drivers-linux-arm64-debug', 'linux-arm64-debug'],
    const <String>[
      'manifest/drivers-linux-x86-64-release',
      'linux-x86-64-release'
    ],
    const <String>[
      'manifest/drivers-linux-arm64-release',
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
  Widget build(BuildContext context) => new MaterialApp(
        title: 'Fuchsia Build Status',
        theme: new ThemeData(
          primaryColor: _kFuchsiaColor,
        ),
        home: new _DashboardPage(title: 'Fuchsia Build Status'),
      );
}

class _DashboardPage extends StatefulWidget {
  _DashboardPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _DashboardPageState createState() => new _DashboardPageState();
}

class _DashboardPageState extends State<_DashboardPage> {
  Map<String, Map<String, BuildInfo>> _targetsResults;
  DateTime _startTime = new DateTime.now();
  DateTime _lastFailTime;
  DateTime _lastPassTime;
  DateTime _lastRefreshed;

  @override
  void initState() {
    super.initState();
    // From the targets map, create a data structure which we'll be populating
    // the build results into, as they come in async.
    _targetsResults = new Map<String, Map<String, BuildInfo>>();

    _kTargetsMap
        .forEach((String categoryName, List<List<String>> buildConfigs) {
      Map<String, BuildInfo> map = new Map<String, BuildInfo>();
      buildConfigs.forEach((List<String> config) {
        map[config[1]] = new BuildInfo(
          status: BuildStatus.unknown,
          url: 'http://www.google.com',
        );
      });
      _targetsResults[categoryName] = map;
    });

    new Timer.periodic(
      const Duration(seconds: 60),
      (_) => _refreshStatus(),
    );
    _refreshStatus();
  }

  // Refresh status an ALL builds.
  void _refreshStatus() {
    _lastRefreshed = new DateTime.now().toLocal();
    // fetch config status for ONE item.
    Future<Null> _fetchConfigStatus(
      String categoryName,
      String buildName,
      String url,
    ) async {
      BuildStatus status = BuildStatus.parseError;
      String html;
      String errorMessage;
      _targetsResults['$categoryName']['$buildName'].lastRefreshStarted =
          new DateTime.now();
      _targetsResults['$categoryName']['$buildName'].lastRefreshEnded = null;

      try {
        http.Response response = await http.get(url);
        html = response.body;
        if (html == null) {
          errorMessage =
              'Status ${response.statusCode}\n${response.reasonPhrase}';
        }
      } catch (error) {
        status = BuildStatus.networkError;
        errorMessage = 'Error receiving response:\n$error';
      }
      _targetsResults['$categoryName']['$buildName'].lastRefreshEnded =
          new DateTime.now();

      if (html == null) {
        status = BuildStatus.networkError;
      } else {
        dom.Document domTree = parse(html);
        List<dom.Element> trs = domTree.querySelectorAll('tr');
        for (dom.Element tr in trs) {
          if (tr.className == "danger") {
            status = BuildStatus.failure;
            break;
          } else if (tr.className == "success") {
            status = BuildStatus.success;
            break;
          }
        }
      }

      _targetsResults['$categoryName']['$buildName'].status = status;
      _targetsResults['$categoryName']['$buildName'].url = url;
      _targetsResults['$categoryName']['$buildName'].errorMessage =
          errorMessage;
      _updatePassFailTime();
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
    setState(() {});
  } // _refreshStatus

  void _updatePassFailTime() {
    if (_targetsResults.values.every(
      (Map<String, BuildInfo> category) => category.values.every(
            (BuildInfo buildInfo) => buildInfo.status == BuildStatus.success,
          ),
    )) {
      if (_lastPassTime == null) {
        _lastPassTime = new DateTime.now();
        _lastFailTime = null;
      }
    } else {
      if (_lastFailTime == null) {
        _lastFailTime = new DateTime.now();
        _lastPassTime = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> rows = <Widget>[];

    _targetsResults.forEach((
      String category,
      Map<String, BuildInfo> buildStati,
    ) {
      rows.add(
        new Expanded(
          child: new Container(
            margin: const EdgeInsets.only(left: _kSpaceBetween),
            child: new Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.max,
              children: buildStati.keys
                  .map(
                    (String name) => new Expanded(
                          child: new Container(
                            margin: const EdgeInsets.only(
                              right: _kSpaceBetween,
                              top: _kSpaceBetween,
                            ),
                            child: new BuildStatusWidget(
                              type: category,
                              name: name,
                              bi: buildStati[name],
                              onTap: () => UrlLauncher.launch(
                                    buildStati[name].url,
                                  ),
                            ),
                          ),
                        ),
                  )
                  .toList(),
            ),
          ),
        ),
      );
    });

    rows.add(
      new InfoText(
        startTime: _startTime,
        lastFailTime: _lastFailTime,
        lastPassTime: _lastPassTime,
        lastRefreshed: _lastRefreshed,
      ),
    );

    return new Scaffold(
      backgroundColor: Colors.white70,
      appBar: Platform.isFuchsia
          ? null
          : new AppBar(title: new Text('Fuchsia Build Status')),
      body: new Column(children: rows),
      floatingActionButton: new FloatingActionButton(
        backgroundColor: _kFuchsiaColor,
        onPressed: _refreshStatus,
        tooltip: 'Refresh',
        child: new Icon(Icons.refresh),
      ),
    );
  }
}
