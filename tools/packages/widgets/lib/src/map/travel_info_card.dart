// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:models/map.dart';

final Map<TravelMode, IconData> _kTravelModeIcons = <TravelMode, IconData>{
  TravelMode.driving: Icons.directions_car,
  TravelMode.transit: Icons.directions_subway,
  TravelMode.bicycling: Icons.directions_bike,
  TravelMode.walking: Icons.directions_walk,
};

final Map<TravelMode, String> _kTravelModeLabels = <TravelMode, String>{
  TravelMode.driving: 'drive',
  TravelMode.transit: 'transit',
  TravelMode.bicycling: 'ride',
  TravelMode.walking: 'walk',
};

/// UI Widget to show travel times
class TravelInfoCard extends StatelessWidget {
  /// Travel info for various travel modes
  final Map<TravelMode, TravelInfo> travelInfo;

  /// Constructor
  TravelInfoCard({
    Key key,
    @required this.travelInfo,
  })
      : super(key: key) {
    assert(travelInfo != null);
    assert(travelInfo.containsKey(TravelMode.driving));
    assert(travelInfo.containsKey(TravelMode.walking));
    assert(travelInfo.containsKey(TravelMode.bicycling));
    assert(travelInfo.containsKey(TravelMode.transit));
  }

  Widget _buildTabBar() {
    return new Container(
      decoration: new BoxDecoration(
        border: new Border(
          bottom: new BorderSide(
            color: Colors.grey[300],
          ),
        ),
      ),
      child: new TabBar(
          labelColor: Colors.blue[500],
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: Colors.blue[500],
          tabs: _kTravelModeIcons.keys.map((TravelMode mode) {
            return new Tab(icon: new Icon(_kTravelModeIcons[mode]));
          }).toList()),
    );
  }

  Widget _buildTabBarView() {
    return new TabBarView(
      children: _kTravelModeIcons.keys.map(_buildTravelInfo).toList(),
    );
  }

  Widget _buildTravelInfo(TravelMode mode) {
    TravelInfo info = travelInfo[mode];
    return new Container(
      padding: const EdgeInsets.all(16.0),
      child: new Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          new Container(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: new Text('${info.distanceText} away'),
          ),
          new Text(
            '${info.durationText} ${_kTravelModeLabels[mode]}',
            style: new TextStyle(
              fontSize: 26.0,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return new Material(
      child: new DefaultTabController(
        length: TravelMode.values.length,
        child: new Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          _buildTabBar(),
          new Expanded(
            child: _buildTabBarView(),
          )
        ]),
      ),
    );
  }
}
