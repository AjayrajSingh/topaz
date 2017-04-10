// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';
import 'package:intl/intl.dart';

import 'dashboard_module_model.dart';

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
  @override
  _InfoTextState createState() => new _InfoTextState();
}

class _InfoTextState extends State<InfoText> {
  Timer _timer;
  DateTime _targetTime;

  @override
  void initState() {
    super.initState();
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
              text: 'Up ',
              style: _kUnimportantStyle,
              children: <TextSpan>[
                new TextSpan(
                  text: _toConciseString(
                    new DateTime.now().difference(model.startTime),
                  ),
                  style: _kImportantStyle,
                ),
              ],
            ),
          ),
        ];

        if (model.lastFailTime != null) {
          Duration lastFailureTime =
              new DateTime.now().difference(model.lastFailTime);

          rowChildren.add(
            new RichText(
              text: new TextSpan(
                text: 'Failing ',
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
        } else if (model.lastPassTime != null) {
          Duration lastPassTime = new DateTime.now().difference(
            model.lastPassTime,
          );

          rowChildren.add(
            new RichText(
              text: new TextSpan(
                text: 'Passing ',
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
      });

  void _updateUptime() {
    setState(() {
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
