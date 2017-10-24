// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

/// Header for the concert guide list
class ConcertGuideHeader extends StatelessWidget {
  static final DateFormat _kMonthFormat = new DateFormat('MMMM y');

  String get _listTitle =>
      'Concert Guide  -  ${_kMonthFormat.format(new DateTime.now())}';

  @override
  Widget build(BuildContext context) {
    return new LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return new Container(
          decoration: new BoxDecoration(
            image: new DecorationImage(
              image: const AssetImage(
                'packages/concert_widgets/res/concert_bg.jpg',
              ),
              fit: BoxFit.cover,
            ),
          ),
          child: new Center(
            child: new Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                new Container(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: new Image.asset(
                    'packages/concert_widgets/res/plat_logo.png',
                    height: constraints.maxHeight * 0.3,
                    width: constraints.maxHeight * 0.3,
                  ),
                ),
                new Text(
                  _listTitle,
                  style: new TextStyle(
                    color: Colors.white,
                    fontSize: min(constraints.maxWidth * 0.06, 48.0),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
