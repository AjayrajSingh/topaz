// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:models/weather.dart';

const double _kIconSize = 80.0;
const double _kMaxWidth = 250.0;
final Color _kTextColor = Colors.blueGrey[700];

/// UI Widget that represents a weather forecast card
class ForecastCard extends StatelessWidget {
  /// Weather data
  final Forecast forecast;

  /// Constructor
  ForecastCard({
    Key key,
    @required this.forecast,
  })
      : super(key: key) {
    assert(forecast != null);
  }

  @override
  Widget build(BuildContext context) {
    return new Container(
      constraints: new BoxConstraints(
        maxWidth: _kMaxWidth,
      ),
      padding: const EdgeInsets.all(16.0),
      child: new Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          new Text(
            'Weather forecast',
            style: new TextStyle(
              color: _kTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          new Container(
            margin: const EdgeInsets.only(top: 8.0),
            child: new Row(
              children: <Widget>[
                new Expanded(
                  child: new Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      new Text(
                        '${forecast.temperature.toInt()}°',
                        style: new TextStyle(
                          color: _kTextColor,
                          fontSize: 48.0,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      new Text(
                        forecast.locationName,
                        style: new TextStyle(
                          color: _kTextColor,
                          fontSize: 12.0,
                        ),
                      ),
                    ],
                  ),
                ),
                new Image.network(
                  forecast.iconUrl,
                  height: _kIconSize,
                  width: _kIconSize,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
