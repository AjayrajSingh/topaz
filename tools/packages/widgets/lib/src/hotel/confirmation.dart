// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

const double _kMaxWidth = 650.0;

/// Scaffold Hotel Confirmation Module
class Confirmation extends StatelessWidget {
  /// Callback for when the manage booking button is tapped
  final VoidCallback onTapManageBooking;

  /// Constructor
  Confirmation({
    Key key,
    this.onTapManageBooking,
  })
      : super(key: key);

  Widget _buildTitleSection(ThemeData theme) {
    return new Container(
      padding: const EdgeInsets.all(40.0),
      child: new Row(
        children: <Widget>[
          new Expanded(
            flex: 2,
            child: new Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                new Text(
                  'Hello Aparna,',
                  style: theme.textTheme.headline.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                new Text(
                  'Your trip to San Francisco is coming up!',
                  style: theme.textTheme.headline.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          new Expanded(
            flex: 1,
            child: new Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                new Container(
                  margin: new EdgeInsets.only(
                    left: 8.0,
                    bottom: 20.0,
                  ),
                  child: new Text(
                    'reservation code: TJY372',
                    style: theme.textTheme.body2.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                new FlatButton(
                  color: Colors.deepOrange[100],
                  child: new Text(
                    'manage booking > ',
                    style: theme.textTheme.body2.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: () => onTapManageBooking?.call(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(ThemeData theme) {
    return new Container(
      margin: const EdgeInsets.only(
        left: 40.0,
        right: 40.0,
        bottom: 40.0,
      ),
      padding: const EdgeInsets.all(40.0),
      decoration: new BoxDecoration(
        color: Colors.deepOrange[500],
        borderRadius: new BorderRadius.all(
          const Radius.circular(20.0),
        ),
      ),
      child: new Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          new Expanded(
            flex: 2,
            child: new Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                new Text(
                  'The Loft SF',
                  style: theme.textTheme.display1.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                new Text(
                  'Union Square',
                  style: theme.textTheme.display1.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          new Expanded(
            flex: 1,
            child: new Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                new Text(
                  'Jun 24',
                  style: theme.textTheme.display1.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                new Text(
                  'check in',
                  style: theme.textTheme.headline.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          new Expanded(
            flex: 1,
            child: new Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                new Text(
                  'Jun 30',
                  style: theme.textTheme.display1.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                new Text(
                  'check out',
                  style: theme.textTheme.headline.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return new Container(
      constraints: new BoxConstraints(
        maxWidth: _kMaxWidth,
      ),
      color: Colors.white,
      child: new Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          new Container(
            child: new Image.asset(
              'packages/widgets/res/hotel_banner.png',
              height: 85.0,
              fit: BoxFit.cover,
            ),
          ),
          _buildTitleSection(theme),
          _buildDetailSection(theme),
          new Container(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: new Image.network(
              'https://cdn.pixabay.com/photo/2016/06/10/01/05/hotel-room-1447201_960_720.jpg',
              height: 250.0,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }
}
