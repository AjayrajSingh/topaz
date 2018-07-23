// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'system_info_model.dart';

TextStyle _labelTextStyle() =>
    TextStyle(color: Colors.black, fontSize: 18.0, fontWeight: FontWeight.w700);

TextStyle _textStyle() =>
    TextStyle(color: Colors.grey, fontSize: 25.0, fontWeight: FontWeight.w700);

class Dashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ScopedModelDescendant<SystemInfoModel>(
          builder: (
        BuildContext context,
        Widget child,
        SystemInfoModel model,
      ) =>
              _dashboardProperties(model));

  Widget _dashboardProperties(SystemInfoModel model) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          elevation: 8.0,
          backgroundColor: Colors.white,
          title: Text('System Dashboard',
              style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                  fontSize: 30.0)),
        ),
        body: StaggeredGridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12.0,
          mainAxisSpacing: 12.0,
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          children: <Widget>[
            _buildTile(_cpuUtilization(model)),
            _buildTile(_fanSpeed(model)),
            _buildTile(_temperature(model)),
            _buildTile(_bigCluster(model)),
            _buildTile(_littleCluster(model)),
          ],
          staggeredTiles: [
            StaggeredTile.extent(2, 130.0),
            StaggeredTile.extent(1, 175.0),
            StaggeredTile.extent(1, 175.0),
            StaggeredTile.extent(2, 190.0),
            StaggeredTile.extent(2, 190.0),
          ],
        ));
  }

  Widget _cpuUtilization(SystemInfoModel model) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Material(
              borderRadius: BorderRadius.circular(12.0),
              child: Container(
                height: 80.0,
                width: 180.0,
                child: LinearProgressIndicator(
                  value: model.cpuUtil / 100,
                  backgroundColor: Colors.greenAccent,
                  valueColor: new AlwaysStoppedAnimation<Color>(Colors.red),
                ),
              ),
            ),
            Column(
              children: <Widget>[
                Text('CPU Utilization',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 20.0,
                        fontWeight: FontWeight.w700)),
                Padding(padding: EdgeInsets.only(bottom: 12.0)),
                Text('${model.cpuUtil} %',
                    style: TextStyle(
                        color: Colors.grey,
                        //fontFamily: ,
                        fontWeight: FontWeight.w700,
                        fontSize: 40.0))
              ],
            ),
          ]),
    );
  }

  Widget _fanSpeed(SystemInfoModel model) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Material(
                color: Colors.lightBlue,
                shape: CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Icon(Icons.settings_applications,
                      color: Colors.white, size: 30.0),
                )),
            Padding(padding: EdgeInsets.only(bottom: 8.0)),
            Text('Fan Speed', style: _labelTextStyle()),
            Padding(padding: EdgeInsets.only(bottom: 6.0)),
            Text('${model.fanLevel}', style: _textStyle()),
          ]),
    );
  }

  Widget _temperature(SystemInfoModel model) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Material(
                color: Colors.green[400],
                shape: CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Icon(Icons.ac_unit, color: Colors.white, size: 30.0),
                )),
            Padding(padding: EdgeInsets.only(bottom: 8.0)),
            Text('Temperature', style: _labelTextStyle()),
            Padding(padding: EdgeInsets.only(bottom: 6.0)),
            Text('${model.temperature}˚C', style: _textStyle()),
          ]),
    );
  }

  Widget _bigCluster(SystemInfoModel model) {
    return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Big Cluster Details',
                style: TextStyle(color: Colors.redAccent)),
            Padding(padding: EdgeInsets.only(top: 10.0)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Material(
                    color: Colors.indigo[500],
                    shape: CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Icon(Icons.broken_image,
                          color: Colors.white, size: 30.0),
                    )),
                Material(
                    color: Colors.amber,
                    shape: CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child:
                          Icon(Icons.flash_on, color: Colors.white, size: 30.0),
                    )),
              ],
            ),
            Padding(padding: EdgeInsets.only(top: 10.0)),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Frequency', style: _labelTextStyle()),
                  Text('Voltage', style: _labelTextStyle()),
                ]),
            Padding(padding: EdgeInsets.only(top: 10.0)),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('${model.bigClusterFrequency} GHz', style: _textStyle()),
                  Text('${model.bigClusterVoltage} V', style: _textStyle()),
                ])
          ],
        ));
  }

  Widget _littleCluster(SystemInfoModel model) {
    return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Little Cluster Details',
                style: TextStyle(color: Colors.redAccent)),
            Padding(padding: EdgeInsets.only(top: 10.0)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Material(
                    color: Colors.indigo[500],
                    shape: CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Icon(Icons.broken_image,
                          color: Colors.white, size: 30.0),
                    )),
                Material(
                    color: Colors.amber,
                    shape: CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child:
                          Icon(Icons.flash_on, color: Colors.white, size: 30.0),
                    )),
              ],
            ),
            Padding(padding: EdgeInsets.only(top: 10.0)),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Frequency', style: _labelTextStyle()),
                  Text('Voltage', style: _labelTextStyle()),
                ]),
            Padding(padding: EdgeInsets.only(top: 10.0)),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('${model.littleClusterFrequency} GHz', style: _textStyle()),
                  Text('${model.littleClusterVoltage} V', style: _textStyle()),
                ])
          ],
        ));
  }

  Widget _buildTile(Widget child, {Function() onTap}) {
    return PhysicalModel(
        elevation: 16.0,
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        shadowColor: Color(0x802196F3),
        child: child);
  }
}
