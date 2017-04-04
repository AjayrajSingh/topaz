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
import 'package:intl/intl.dart';

enum _BuildStatus { unknown, networkError, parseError, success, failure }

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

const String _kBaseURL = 'https://luci-scheduler.appspot.com/jobs/';
const Color _kFuchsiaColor = const Color(0xFFFF0080);

class _BuildInfo {
  _BuildStatus status = _BuildStatus.unknown;
  String url;
  String errorMessage;
  DateTime lastRefreshStarted;
  DateTime lastRefreshEnded;

  _BuildInfo({this.status, this.url, this.errorMessage});
}

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
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Fuchsia Build Status',
      theme: new ThemeData(
        primaryColor: _kFuchsiaColor,
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
  DateTime _lastFailTime;
  DateTime _lastPassTime;
  DateTime _lastRefreshed;

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
      _BuildStatus status = _BuildStatus.parseError;
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
          if (_lastFailTime == null) {
            _lastFailTime = new DateTime.now();
            _lastPassTime = null;
          }
        }
      } catch (error) {
        status = _BuildStatus.networkError;
        errorMessage = 'Error receiving response:\n$error';
        if (_lastFailTime == null) {
          _lastFailTime = new DateTime.now();
          _lastPassTime = null;
        }
      }
      _targetsResults['$categoryName']['$buildName'].lastRefreshEnded =
          new DateTime.now();

      if (html == null) {
        status = _BuildStatus.networkError;
      } else {
        if (_lastPassTime == null) {
          _lastPassTime = new DateTime.now();
          _lastFailTime = null;
        }

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
      _targetsResults['$categoryName']['$buildName'].errorMessage =
          errorMessage;
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
        return Colors.grey[300];
    }
  }

  Widget _buildResultWidget(String type, String name, _BuildInfo bi) {
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

    return new Expanded(
      child: new GestureDetector(
        onTap: () {
          _launchUrl(bi.url);
        },
        child: new Container(
          decoration: new BoxDecoration(
            backgroundColor: _colorFromBuildStatus(bi.status),
            borderRadius: new BorderRadius.circular(8.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          margin: const EdgeInsets.only(
            right: _kSpaceBetween,
            top: _kSpaceBetween,
          ),
          child: new Stack(children: stackChildren),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> rows = <Widget>[];

    _targetsResults.forEach((String k, Map<String, _BuildInfo> v) {
      // the builds
      List<Widget> builds = v.keys
          .map((String name) => _buildResultWidget(k, name, v[name]))
          .toList();

      rows.add(
        new Expanded(
          child: new Container(
            margin: const EdgeInsets.only(left: _kSpaceBetween),
            child: new Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.max,
              children: builds,
            ),
          ),
        ),
      );
    });

    rows.add(
      new _InfoText(
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

class _InfoText extends StatefulWidget {
  final DateTime startTime;
  final DateTime lastFailTime;
  final DateTime lastPassTime;
  final DateTime lastRefreshed;

  _InfoText({
    this.startTime,
    this.lastFailTime,
    this.lastPassTime,
    this.lastRefreshed,
  });

  @override
  _InfoTextState createState() => new _InfoTextState();
}

class _InfoTextState extends State<_InfoText> {
  Duration _uptime;
  Timer _timer;

  @override
  void initState() {
    super.initState();
    _uptime = const Duration();
    _timer = new Timer(
      const Duration(seconds: 1),
      _updateUptime,
    );
  }

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
    _timer = null;
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> rowChildren = <Widget>[
      new RichText(
        textAlign: TextAlign.right,
        text: new TextSpan(
          text: 'Updated ',
          style: _kUnimportantStyle,
          children: <TextSpan>[
            new TextSpan(
              text: new DateFormat('MM/dd h:mm a', 'en_US').format(
                config.lastRefreshed,
              ),
              style: _kImportantStyle,
            ),
          ],
        ),
      ),
      new RichText(
        textAlign: TextAlign.right,
        text: new TextSpan(
          text: 'Up for ',
          style: _kUnimportantStyle,
          children: <TextSpan>[
            new TextSpan(
              text: _toConciseString(_uptime),
              style: _kImportantStyle,
            ),
          ],
        ),
      ),
    ];

    if (config.lastFailTime != null) {
      Duration lastFailureTime =
          new DateTime.now().difference(config.lastFailTime);

      rowChildren.add(
        new RichText(
          text: new TextSpan(
            text: 'Failing for ',
            style: _kUnimportantStyle,
            children: <TextSpan>[
              new TextSpan(
                text: _toConciseString(lastFailureTime),
                style: _kImportantStyle,
              ),
            ],
          ),
        ),
      );
    } else if (config.lastPassTime != null) {
      Duration lastPassTime = new DateTime.now().difference(
        config.lastPassTime,
      );

      rowChildren.add(
        new RichText(
          text: new TextSpan(
            text: 'Passing for ',
            style: _kUnimportantStyle,
            children: <TextSpan>[
              new TextSpan(
                text: _toConciseString(lastPassTime),
                style: _kImportantStyle,
              ),
            ],
          ),
        ),
      );
    }

    return new Container(
      height: 44.0,
      margin: const EdgeInsets.only(left: 12.0, right: 92.0),
      child: new Center(
        child: new Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: rowChildren,
        ),
      ),
    );
  }

  void _updateUptime() {
    setState(() {
      _uptime = new DateTime.now().difference(config.startTime);
      _timer = new Timer(const Duration(seconds: 1), _updateUptime);
    });
  }

  static String _toConciseString(Duration duration) => duration.inSeconds < 60
      ? '${duration.inSeconds}s'
      : duration.inMinutes < 60
          ? '${duration.inMinutes}m'
          : duration.inHours < 24
              ? '${duration.inHours}h'
              : '${duration.inDays}d';
}
