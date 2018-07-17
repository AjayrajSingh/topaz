// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

/// Logo Yellow
const Color yellow = const Color(0xFFFFFD3B);

/// Logo Red
const Color red = const Color(0xFFFC5D60);

/// Logo Blue
const Color blue = const Color(0xFF4D8AE9);

/// Logo Border
const Color borderColor = const Color(0xFF353535);

/// Programmatic implementation of Static Mondrian Logo
class MondrianLogo extends StatelessWidget {
  /// A Programmatic Mondrian Logo
  const MondrianLogo();

  @override
  Widget build(BuildContext context) {
    return new LayoutBuilder(
      builder: (BuildContext layoutContext, BoxConstraints constraints) {
        double fontPoint = constraints.maxHeight / 2.3;
        double borderWidth = constraints.maxWidth / 37.5;
        double borderRadius = constraints.maxWidth * 0.0625;
        return new Material(
          child: new Container(
            child: new Row(
              children: <Widget>[
                new Flexible(
                  flex: 1,
                  child: new Container(
                    decoration: new BoxDecoration(
                      color: blue,
                      border: new Border(
                        right: new BorderSide(
                            color: borderColor, width: borderWidth),
                      ),
                    ),
                  ),
                ),
                new Flexible(
                  flex: 1,
                  child: new Column(
                    children: <Widget>[
                      new Flexible(
                        flex: 1,
                        child: new Container(
                          decoration: new BoxDecoration(
                            color: red,
                            border: new Border(
                              bottom: new BorderSide(
                                  color: borderColor, width: borderWidth),
                            ),
                          ),
                        ),
                      ),
                      new Flexible(
                        flex: 1,
                        child: new Container(
                          child: new Center(
                            child: new Text(
                              'M',
                              style: new TextStyle(
                                  fontFamily: 'Kanit', // ToDo - djmurphy
                                  fontStyle: FontStyle.normal,
                                  fontSize: fontPoint),
                            ),
                          ),
                          decoration: const BoxDecoration(color: yellow),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
            foregroundDecoration: new BoxDecoration(
              borderRadius: new BorderRadius.all(
                new Radius.circular(borderRadius),
              ),
              border: new Border.all(width: borderWidth, color: borderColor),
            ),
          ),
          borderRadius: new BorderRadius.all(
            new Radius.circular(borderRadius),
          ),
        );
      },
    );
  }
}
