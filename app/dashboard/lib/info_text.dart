// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.widgets/model.dart';
import 'package:intl/intl.dart';

import 'package:dashboard/dashboard_module_model.dart';

const double _kFontSize = 20.0;

const TextStyle _kImportantStyle = const TextStyle(
  color: Colors.black,
  fontSize: _kFontSize,
  fontWeight: FontWeight.w500,
);

final TextStyle _kUnimportantStyle = _kImportantStyle.copyWith(
  fontWeight: FontWeight.w300,
);

/// A callback that returns a percentage of the build info requests that have
/// timed out.
typedef _GetTimeoutRate = double Function();

/// Displays important info about the builds.
class InfoText extends StatefulWidget {
  /// A percentage representing no. timed out requests / no. total requests.
  final _GetTimeoutRate timeoutRate;

  /// Initializing constructor.
  const InfoText({this.timeoutRate});

  @override
  _InfoTextState createState() => new _InfoTextState(timeoutRate: timeoutRate);
}

class _InfoTextState extends State<InfoText> {
  Timer _timer;
  DateTime _targetTime;

  final _GetTimeoutRate timeoutRate;

  _InfoTextState({this.timeoutRate});

  @override
  void initState() {
    super.initState();
    _timer = new Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(() {}),
    );
    if (new File('/data/dashboard_target').existsSync()) {
      new File('/data/dashboard_target')
          .readAsString()
          .then((String timestamp) {
        try {
          setState(() {
            _targetTime = (timestamp != null && timestamp.isNotEmpty)
                ? DateTime.parse(timestamp.trim())
                : 0;
          });
        } on FormatException catch (_) {
          log.severe(
              'Error: Could not parse ${timestamp.trim()} as a DateTime!');
        }
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
    _timer = null;
  }

  @override
  Widget build(BuildContext context) =>
      new ScopedModelDescendant<DashboardModuleModel>(builder: (
        BuildContext context,
        Widget child,
        DashboardModuleModel model,
      ) {
        List<Widget> rowChildren = <Widget>[
          new RichText(
            textAlign: TextAlign.right,
            text: new TextSpan(
              text: 'Updated ',
              style: _kUnimportantStyle,
              children: <TextSpan>[
                new TextSpan(
                  text: model.lastRefreshed == null
                      ? ''
                      : new DateFormat('MM/dd h:mm a', 'en_US').format(
                          model.lastRefreshed,
                        ),
                  style: _kImportantStyle,
                ),
              ],
            ),
          ),
          new RichText(
            textAlign: TextAlign.right,
            text: new TextSpan(
              text: 'Timeout Rate ',
              style: _kUnimportantStyle,
              children: <TextSpan>[
                new TextSpan(
                  text: '${timeoutRate().ceil()}%',
                  style: _kImportantStyle,
                )
              ],
            ),
          ),
          new RichText(
            textAlign: TextAlign.right,
            text: new TextSpan(
              text: 'Up ',
              style: _kUnimportantStyle,
              children: <TextSpan>[
                new TextSpan(
                  text: toConciseString(
                    new DateTime.now().difference(model.startTime),
                  ),
                  style: _kImportantStyle,
                ),
              ],
            ),
          ),
        ];

        if (model.devices != null) {
          rowChildren.add(
            new RichText(
              text: new TextSpan(
                text: 'Devices ',
                style: _kUnimportantStyle,
                children: <TextSpan>[
                  new TextSpan(
                    text: '${model.devices.length}',
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
                    text: toConciseString(
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
      });
}

/// Converts [duration] to a short string representing the duration based on
/// it's largest unit.  Examples include '6s', '42m', '3h', and '12d'.
String toConciseString(Duration duration) => duration.inSeconds.abs() < 60
    ? '<1m'
    : duration.inMinutes.abs() < 60
        ? '${duration.inMinutes}m'
        : duration.inHours.abs() < 24
            ? '${duration.inHours}h'
            : '${duration.inDays}d';
