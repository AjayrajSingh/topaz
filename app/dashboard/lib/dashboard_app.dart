import 'package:flutter/material.dart';
import 'package:flutter/http.dart' as http;

import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'dart:io';
import 'dart:core';
import 'dart:async';

enum BuildStatus {
  UNKNOWN, NETWORKERROR, PARSEERROR, SUCCESS, FAILURE
}

// ----------------------------------------------------------------------------
// EDIT BELOW TO ADD configs

final String kBaseURL = 'https://luci-scheduler.appspot.com/jobs/';

var targets_map = {
  'fuchsia': [
    ['fuchsia/linux-x86-64-debug', 'linux-x86-64-debug'],
    ['fuchsia/linux-arm64-debug', 'linux-arm64-debug'],
    ['fuchsia/linux-x86-64-release', 'linux-x86-64-release'],
    ['fuchsia/linux-arm64-release', 'linux-arm64-release'],
  ],
  'fuchsia-drivers': [
    ['fuchsia/drivers-linux-x86-64-debug', 'linux-x86-64-debug'],
    ['fuchsia/drivers-linux-arm64-debug', 'linux-arm64-debug'],
    ['fuchsia/drivers-linux-x86-64-release', 'linux-x86-64-release'],
    ['fuchsia/drivers-linux-arm64-release', 'linux-arm64-release'],
  ],
  'magenta': [
    ['magenta/arm64-linux-gcc', 'arm64-linux-gcc'],
    ['magenta/x86-64-linux-gcc', 'x86-64-linux-gcc'],
    ['magenta/arm64-linux-clang', 'arm64-linux-clang'],
    ['magenta/x86-64-linux-clang', 'x86-64-linux-clang'],
  ],
  'jiri': [
    ['jiri/linux-x86-64', 'linux-x86-64'],
    ['jiri/mac-x86-64', 'mac-x86-64'],
  ]
};


class DashboardApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Fuchsia Build Status',
      theme: new ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see
        // the application has a blue toolbar. Then, without quitting
        // the app, try changing the primarySwatch below to Colors.green
        // and press "r" in the console where you ran "flutter run".
        // We call this a "hot reload". 
        primarySwatch: Colors.blue,
      ),
      home: new DashboardPage(title: 'Fuchsia Build Status'),
    );
  }
}

class DashboardPage extends StatefulWidget {
  DashboardPage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful,
  // meaning that it has a State object (defined below) that contains
  // fields that affect how it looks.

  // This class is the configuration for the state. It holds the
  // values (in this case the title) provided by the parent (in this
  // case the App widget) and used by the build method of the State.
  // Fields in a Widget subclass are always marked "final".

  final String title;

  @override
  _DashboardPageState createState() => new _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  BuildStatus _status = BuildStatus.UNKNOWN;
  var targets_results;
  Timer _refreshTimer;

  @override
  initState() {
    // From the targets map, create a data structure which we'll be populating
    // the build results into, as they come in async.
    targets_results = new Map();

    targets_map.forEach((categoryName,buildConfigs) {
        var this_map = new Map<String, BuildStatus>();
        for(var config in buildConfigs) {
         this_map[config[1]] =BuildStatus.UNKNOWN;
        }
        targets_results[categoryName] = this_map;
      });

    _refreshTimer = new Timer.periodic(const Duration(seconds: 5), _refreshTimerFired);
    _refreshStatus();
  }

  void _refreshTimerFired(Timer t) {
    _refreshStatus();
  }

  // Refresh status an ALL builds.
  void _refreshStatus() {

    // fetch config status for ONE item.
    void _fetchConfigStatus(categoryName, buildName, url) {
      BuildStatus status = BuildStatus.PARSEERROR;
      http.get(url).then<Null>((http.Response response) {
        String html = response.body;
        if (html == null) {
          print("Failed to load dashboard page ${url}");
          status = BuildStatus.NETWORKERROR;
          return null;
        }
        var dom_tree = parse(html);
        List<dom.Element> trs = dom_tree.querySelectorAll('tr');
        for (var tr in trs) {
          if (tr.className == "danger") {
            status = BuildStatus.FAILURE;
            break;
          }
          else if (tr.className == "success") {
            status = BuildStatus.SUCCESS;
            break;
          }
        }

        targets_results['${categoryName}']['${buildName}'] = status;
        // invalidate the state
        setState( () {} );
      }); 

    }

    // kick off requests for all the build configs desired. As 
    // these reults come in they will be stuffed into the targets_results map.
    targets_map.forEach((categoryName, buildConfigs){
        for(var config in buildConfigs) {
          String url = kBaseURL + config[0];
          //print(url);
          _fetchConfigStatus(categoryName, config[1], url);
        }
      });


    setState(() {
      // This call to setState tells the Flutter framework that
      // something has changed in this State, which causes it to rerun
      // the build method below so that the display can reflect the
      // updated values.
    });
  }

  Color _colorFromBuildStatus(BuildStatus status) {
    switch (status) {
      case BuildStatus.SUCCESS:
        return Colors.green[100];
      case BuildStatus.FAILURE:
        return Colors.red[100];
      default:
        return Colors.white;
    }
  }

  Widget _buildResultWidget(String name, BuildStatus status) {
    return new Container(
        decoration: new BoxDecoration(backgroundColor: _colorFromBuildStatus(status)),
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: new Text(name,
          style:new TextStyle(color:Colors.black, fontSize:24.0)),
      );
  }

  @override
  Widget build(BuildContext context) { 
    // This method is rerun every time setState is called, for instance
    // as done by the _refreshStatus method above.
    // The Flutter framework has been optimized to make rerunning
    // build methods fast, so that you can just rebuild anything that
    // needs updating rather than having to individually change
    // instances of widgets.

    var rows = new List();
    targets_results.forEach((k,v) {

        rows.add(
          new Container(
            padding: new EdgeInsets.fromLTRB(0.0, 32.0, 0.0, 0.0),
            child:
          new Row(children:[new Text(k, 
          style: new TextStyle(fontSize:16.0))]),
          ),
        );

        var builds = new List();
        v.forEach((name, status) {
          builds.add(_buildResultWidget(name,status));
          });

        rows.add(new Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              mainAxisSize: MainAxisSize.max,
              children:builds));
      });


    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Fuchsia Build Status'),
      ),
      body: new Container( 
        padding: new EdgeInsets.all(20.0),
        child: new Column (
          children: rows,
        ), ),

      floatingActionButton: new FloatingActionButton(
        onPressed: _refreshStatus,
        tooltip: 'Increment',
        child: new Icon(Icons.refresh),
      ), // This trailing comma tells the Dart formatter to use
      // a style that looks nicer for build methods.
    );
  }
}
