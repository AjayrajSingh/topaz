// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:fuchsia_inspect/inspect.dart' as inspect;
import 'roachLogic.dart';

class RoachRuinHome extends StatefulWidget {
  const RoachRuinHome({Key key, this.title, this.inspectNode})
      : super(key: key);
  final String title;
  final inspect.Node inspectNode;

  @override
  _RoachRuinState createState() => _RoachRuinState();
}

class _RoachRuinState extends State<RoachRuinHome> {
  _RoachRuinState({this.inspectNode});
  final inspect.Node inspectNode;
  RoachLogic roachLogic = RoachLogic();

  void updateState() {
    setState(() {
      roachLogic.hammerUp =
          roachLogic.changeHammer(hamIsUp: roachLogic.hammerUp);
      if (roachLogic.hammerUp) {
        roachLogic
          ..currHam = roachLogic.hammerUpright()
          ..currRoach = roachLogic.roachLiving();
      } else {
        roachLogic
          ..currHam = roachLogic.hammerDown()
          ..currRoach = roachLogic.roachNotLiving()
          ..counter = roachLogic.increaseCounter(roachLogic.counter);
      }
      widget.inspectNode
          .stringProperty('Roachstate')
          .setValue('${roachLogic.currRoach}');
      widget.inspectNode
          .stringProperty('Hamstate')
          .setValue('${roachLogic.currHam}');
      widget.inspectNode
          .stringProperty('Counter is')
          .setValue('${roachLogic.counter}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      backgroundColor: Colors.lightGreen,
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Row(mainAxisAlignment: MainAxisAlignment.end, children: <Widget>[
              Text(
                'You hurt this poor roach ${roachLogic.counter} times',
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
              ),
            ]),
            Padding(
              padding: EdgeInsets.all(150.0),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              Image.asset(
                '${roachLogic.currHam}',
                scale: 1.0,
                width: 200.0,
                height: 200.0,
              ),
            ]),
            Padding(
              padding: EdgeInsets.all(8.0),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              Image.asset(
                '${roachLogic.currRoach}',
                scale: 1.0,
                width: 200.0,
                height: 200.0,
              ),
              Image.asset(
                '${roachLogic.person}',
                scale: 1.0,
                width: 200.0,
                height: 200.0,
              ),
            ]),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: updateState,
        tooltip: 'Hit Roach',
        child: Icon(Icons.add),
      ),
    );
  }
}

class RoachGame extends StatelessWidget {
  const RoachGame({this.inspectNode});
  final inspect.Node inspectNode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roach Game',
      theme: ThemeData(primarySwatch: Colors.red),
      home: RoachRuinHome(
          title: 'Welcome to Roach Ruin', inspectNode: inspectNode),
    );
  }
}
