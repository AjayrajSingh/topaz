// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

Future<Null> main() async {
  runApp(
    new LayoutBuilder(
      builder: (_, BoxConstraints constraints) => new Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // Blue panel on left.
              new Positioned(
                left: 0.0,
                top: 0.0,
                bottom: 0.0,
                width: constraints.biggest.width * 0.66,
                child: new PhysicalModel(
                  borderRadius: new BorderRadius.circular(16.0),
                  color: Colors.blue[300],
                  elevation: 20.0,
                  child: new LayoutBuilder(
                    builder: (_, BoxConstraints constraints) => new Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            // Placeholder for search bar.
                            new Positioned(
                              left: constraints.biggest.width * 0.33,
                              top: 24.0,
                              width: constraints.biggest.width * 0.33,
                              height: 32.0,
                              child: new PhysicalModel(
                                borderRadius: new BorderRadius.circular(4.0),
                                color: Colors.red[300],
                                elevation: 15.0,
                                child: new Container(),
                              ),
                            ),

                            // Placeholder for an image.
                            new Positioned(
                              left: 40.0,
                              bottom: 40.0,
                              width: constraints.biggest.width * 0.4,
                              height: constraints.biggest.height * 0.3,
                              child: new PhysicalModel(
                                color: Colors.yellow[300],
                                elevation: 5.0,
                                child: new Container(),
                              ),
                            ),

                            // The sun.
                            new Positioned(
                              left: constraints.biggest.width * 0.5,
                              bottom: -100.0,
                              child: new _Sun(elevation: 10.0),
                            ),
                          ],
                        ),
                  ),
                ),
              ),

              // Green panel on right.
              new Positioned(
                right: 0.0,
                bottom: 0.0,
                width: constraints.biggest.width * 0.4,
                height: constraints.biggest.height * 0.8,
                child: new PhysicalModel(
                  borderRadius: new BorderRadius.circular(16.0),
                  color: Colors.green[300],
                  elevation: 40.0,
                  child: new Container(),
                ),
              ),

              // Future button that crosses panel boundaries.
              new Positioned(
                left: constraints.biggest.width * 0.55,
                top: constraints.biggest.height * 0.70,
                width: constraints.biggest.width * 0.1,
                height: constraints.biggest.width * 0.1,
                child: new PhysicalModel(
                  shape: BoxShape.circle,
                  color: Colors.purple[300],
                  elevation: 45.0,
                  child: new Container(),
                ),
              ),

              // Future button.
              new Positioned(
                left: constraints.biggest.width * 0.65,
                top: constraints.biggest.height * 0.55,
                width: constraints.biggest.height * 0.05,
                height: constraints.biggest.height * 0.05,
                child: new PhysicalModel(
                  shape: BoxShape.circle,
                  color: Colors.brown[300],
                  elevation: 45.0,
                  child: new Container(),
                ),
              ),
            ],
          ),
    ),
  );
}

class _Sun extends StatelessWidget {
  final double elevation;

  _Sun({this.elevation});

  @override
  Widget build(BuildContext context) => new SizedBox(
        width: 220.0,
        height: 220.0,
        child: new Stack(
          children: <Widget>[
            // Top ray.
            new Align(
              alignment: FractionalOffset.center,
              child: new Transform(
                alignment: FractionalOffset.center,
                transform: new Matrix4.translationValues(0.0, 65.0, 0.0),
                child: new Transform(
                  alignment: FractionalOffset.center,
                  transform: new Matrix4.rotationZ(math.PI / 2.0),
                  child: new PhysicalModel(
                    color: Colors.yellow,
                    elevation: elevation,
                    child: new SizedBox(width: 20.0, height: 15.0),
                  ),
                ),
              ),
            ),

            // Bottom ray.
            new Align(
              alignment: FractionalOffset.center,
              child: new Transform(
                alignment: FractionalOffset.center,
                transform: new Matrix4.translationValues(0.0, -65.0, 0.0),
                child: new Transform(
                  alignment: FractionalOffset.center,
                  transform: new Matrix4.rotationZ(math.PI / 2.0),
                  child: new PhysicalModel(
                    color: Colors.yellow,
                    elevation: elevation,
                    child: new SizedBox(width: 20.0, height: 15.0),
                  ),
                ),
              ),
            ),

            // Right ray.
            new Align(
              alignment: FractionalOffset.center,
              child: new Transform(
                alignment: FractionalOffset.center,
                transform: new Matrix4.translationValues(65.0, 0.0, 0.0),
                child: new PhysicalModel(
                  color: Colors.yellow,
                  elevation: elevation,
                  child: new SizedBox(width: 20.0, height: 15.0),
                ),
              ),
            ),

            // Left ray.
            new Align(
              alignment: FractionalOffset.center,
              child: new Transform(
                alignment: FractionalOffset.center,
                transform: new Matrix4.translationValues(-65.0, 0.0, 0.0),
                child: new PhysicalModel(
                  color: Colors.yellow,
                  elevation: elevation,
                  child: new SizedBox(width: 20.0, height: 15.0),
                ),
              ),
            ),

            // Sun.
            new Align(
              alignment: FractionalOffset.center,
              child: new PhysicalModel(
                color: Colors.yellow,
                elevation: elevation,
                shape: BoxShape.circle,
                child: new SizedBox(width: 80.0, height: 80.0),
              ),
            ),

            // Bottom right ray.
            new Align(
              alignment: FractionalOffset.center,
              child: new Transform(
                alignment: FractionalOffset.center,
                transform: new Matrix4.translationValues(
                  64.0 * 0.707,
                  64.0 * 0.707,
                  0.0,
                ),
                child: new Transform(
                  alignment: FractionalOffset.center,
                  transform: new Matrix4.rotationZ(math.PI / 4.0),
                  child: new PhysicalModel(
                    color: Colors.yellow,
                    elevation: elevation,
                    child: new SizedBox(width: 18.0, height: 15.0),
                  ),
                ),
              ),
            ),
            // Top left ray.
            new Align(
              alignment: FractionalOffset.center,
              child: new Transform(
                alignment: FractionalOffset.center,
                transform: new Matrix4.translationValues(
                  -64.0 * 0.707,
                  -64.0 * 0.707,
                  0.0,
                ),
                child: new Transform(
                  alignment: FractionalOffset.center,
                  transform: new Matrix4.rotationZ(math.PI / 4.0),
                  child: new PhysicalModel(
                    color: Colors.yellow,
                    elevation: elevation,
                    child: new SizedBox(width: 18.0, height: 15.0),
                  ),
                ),
              ),
            ),
            // Top right ray.
            new Align(
              alignment: FractionalOffset.center,
              child: new Transform(
                alignment: FractionalOffset.center,
                transform: new Matrix4.translationValues(
                  64.0 * 0.707,
                  -64.0 * 0.707,
                  0.0,
                ),
                child: new Transform(
                  alignment: FractionalOffset.center,
                  transform: new Matrix4.rotationZ(3.0 * math.PI / 4.0),
                  child: new PhysicalModel(
                    color: Colors.yellow,
                    elevation: elevation,
                    child: new SizedBox(width: 18.0, height: 15.0),
                  ),
                ),
              ),
            ),
            // Top right ray.
            new Align(
              alignment: FractionalOffset.center,
              child: new Transform(
                alignment: FractionalOffset.center,
                transform: new Matrix4.translationValues(
                  -64.0 * 0.707,
                  64.0 * 0.707,
                  0.0,
                ),
                child: new Transform(
                  alignment: FractionalOffset.center,
                  transform: new Matrix4.rotationZ(3.0 * math.PI / 4.0),
                  child: new PhysicalModel(
                    color: Colors.yellow,
                    elevation: elevation,
                    child: new SizedBox(width: 18.0, height: 15.0),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
