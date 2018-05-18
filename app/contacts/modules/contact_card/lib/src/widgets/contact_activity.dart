// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

const String _kActivityTitle = 'activity';

/// Widget to display a contact's recent activity
class ContactActivity extends StatelessWidget {
  /// Whether or not to show the header as well
  final bool showHeader;

  /// Constructor
  const ContactActivity({@required this.showHeader})
      : assert(showHeader != null);

  @override
  Widget build(BuildContext context) {
    List<Widget> activityListWidgets = <Widget>[];
    if (showHeader) {
      activityListWidgets.add(
        new Container(
          margin: const EdgeInsets.only(left: 10.0, bottom: 8.0),
          child: new Text(
            _kActivityTitle.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
    activityListWidgets.add(
      new Card(
        child: new Container(
          height: 100.0,
          child: const Center(
            child: const Text('No Activity Yet :('),
          ),
        ),
        elevation: 5.0,
      ),
    );

    double containerTopMargin = showHeader ? 75.0 : 10.0;
    Container activityCardContainer = new Container(
      margin: new EdgeInsets.fromLTRB(45.0, containerTopMargin, 45.0, 10.0),
      child: new ListView(children: activityListWidgets),
    );

    return new Container(
      color: Colors.grey[300],
      child: showHeader
          ? new Stack(
              children: <Widget>[
                new Container(
                  height: 150.0,
                  color: Colors.blue,
                ),
                activityCardContainer,
              ],
            )
          : activityCardContainer,
    );
  }
}
