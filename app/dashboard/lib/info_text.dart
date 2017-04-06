// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const double _kFontSize = 20.0;

final TextStyle _kImportantStyle = new TextStyle(
  color: Colors.black,
  fontSize: _kFontSize,
  fontWeight: FontWeight.w500,
);

final TextStyle _kUnimportantStyle = _kImportantStyle.copyWith(
  fontWeight: FontWeight.w300,
);

class InfoText extends StatefulWidget {
  final DateTime startTime;
  final DateTime lastFailTime;
  final DateTime lastPassTime;
  final DateTime lastRefreshed;

  InfoText({
    this.startTime,
    this.lastFailTime,
    this.lastPassTime,
    this.lastRefreshed,
  });

  @override
  _InfoTextState createState() => new _InfoTextState();
}

class _InfoTextState extends State<InfoText> {
  Duration _uptime;
  Timer _timer;
  DateTime _targetTime;

  @override
  void initState() {
    super.initState();
    _uptime = const Duration();
    _timer = new Timer(
      const Duration(seconds: 1),
      _updateUptime,
    );
    new File('/data/dashboard_target').readAsString().then((String timestamp) {
      try {
        setState(() {
          _targetTime = (timestamp != null && timestamp.isNotEmpty)
              ? DateTime.parse(timestamp.trim())
              : 0;
        });
      } catch (_, __) {
        print('Error: Could not parse ${timestamp.trim()} as a DateTime!');
      }
    });
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

    if (_targetTime != null) {
      rowChildren.add(
        new RichText(
          text: new TextSpan(
            text: 'Remaining ',
            style: _kUnimportantStyle,
            children: <TextSpan>[
              new TextSpan(
                text: _toConciseString(
                  _targetTime.difference(new DateTime.now()),
                ),
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

  static String _toConciseString(
          Duration duration) =>
      duration.inSeconds.abs() < 60
          ? '${duration.inSeconds}s'
          : duration.inMinutes.abs() < 60
              ? '${duration.inMinutes}m'
              : duration.inHours.abs() < 24
                  ? '${duration.inHours}h'
                  : '${duration.inDays}d';
}
