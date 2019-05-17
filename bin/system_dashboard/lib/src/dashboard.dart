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
        body: StaggeredGridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12.0,
          mainAxisSpacing: 12.0,
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          children: <Widget>[
            _buildTile(_utilization(model)),
            _buildTile(_fanSpeedAndTemperature(model)),
            _buildTile(_bigCluster(model)),
            _buildTile(_littleCluster(model)),
          ],
          staggeredTiles: [
            StaggeredTile.extent(1, 130.0),
            StaggeredTile.extent(1, 130.0),
            StaggeredTile.extent(1, 170.0),
            StaggeredTile.extent(1, 170.0),
          ],
        ));
  }

  Widget _utilization(SystemInfoModel model) {
    return Padding(
        padding: EdgeInsets.all(1.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Material(
                  borderRadius: BorderRadius.circular(12.0),
                  child: Container(
                    height: 50.0,
                    width: 90.0,
                    child: LinearProgressIndicator(
                      value: model.cpuUtilization / 100,
                      backgroundColor: Colors.greenAccent,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                    ),
                  ),
                ),
                Material(
                  borderRadius: BorderRadius.circular(12.0),
                  child: Container(
                    height: 50.0,
                    width: 90.0,
                    child: LinearProgressIndicator(
                      value: model.memoryUtilization / 100,
                      backgroundColor: Colors.greenAccent,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                    ),
                  ),
                ),
              ],
            ),
            Padding(padding: EdgeInsets.only(top: 10.0)),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('CPU Usage', style: _labelTextStyle()),
                  Text('Memory Usage', style: _labelTextStyle()),
                ]),
            Padding(padding: EdgeInsets.only(top: 10.0)),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('${model.cpuUtilization} %', style: _textStyle()),
                  Text('${model.memoryUtilization} %', style: _textStyle()),
                ])
          ],
        ));
  }

  Widget _fanSpeedAndTemperature(SystemInfoModel model) {
    return Padding(
        padding: EdgeInsets.all(1.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Material(
                    color: Colors.lightBlue,
                    shape: CircleBorder(),
                    child: Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Icon(Icons.settings_applications,
                          color: Colors.white, size: 30.0),
                    )),
                Material(
                    color: Colors.green[400],
                    shape: CircleBorder(),
                    child: Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Icon(Icons.ac_unit, color: Colors.white, size: 30.0),
                    )),
              ],
            ),
            Padding(padding: EdgeInsets.only(top: 10.0)),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Fan Speed', style: _labelTextStyle()),
                  Text('Temperature', style: _labelTextStyle()),
                ]),
            Padding(padding: EdgeInsets.only(top: 10.0)),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('${model.fanLevel}', style: _textStyle()),
                  Text('${model.temperature}˚C', style: _textStyle()),
                ])
          ],
        ));
  }
  
  Widget _bigCluster(SystemInfoModel model) {
    return Padding(
        padding: EdgeInsets.all(5.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Big Cluster Details',
                style: TextStyle(color: Colors.black)),
            Padding(padding: EdgeInsets.only(top: 10.0)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Material(
                    color: Colors.indigo[500],
                    shape: CircleBorder(),
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Icon(Icons.broken_image,
                          color: Colors.white, size: 30.0),
                    )),
                Material(
                    color: Colors.amber,
                    shape: CircleBorder(),
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
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
        padding: EdgeInsets.all(5.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Little Cluster Details',
                style: TextStyle(color: Colors.black)),
            Padding(padding: EdgeInsets.only(top: 10.0)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Material(
                    color: Colors.indigo[500],
                    shape: CircleBorder(),
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Icon(Icons.broken_image,
                          color: Colors.white, size: 30.0),
                    )),
                Material(
                    color: Colors.amber,
                    shape: CircleBorder(),
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
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
