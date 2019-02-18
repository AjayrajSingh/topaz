// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fuchsia_scenic_flutter/child_view.dart' show ChildView;
import 'package:lib.app.dart/logging.dart';
import 'package:lib.widgets/model.dart';

import '../models/surface/surface.dart';
import '../models/surface/surface_graph.dart';
import 'isometric_widget.dart';

/// Printable names for relation arrangement
const Map<SurfaceArrangement, String> relName =
    const <SurfaceArrangement, String>{
  SurfaceArrangement.none: 'no opinion',
  SurfaceArrangement.copresent: 'co-present',
};

/// Printable names for relation dependency
const Map<SurfaceDependency, String> depName =
    const <SurfaceDependency, String>{
  SurfaceDependency.dependent: 'dependent',
  SurfaceDependency.none: 'independent',
};

/// Show overview of all currently active surfaces in a story
/// and their relationships
class Overview extends StatelessWidget {
  /// Constructor
  const Overview({Key key}) : super(key: key);

  /// Build the ListView of Surface views in SurfaceGraph
  Widget buildGraphList(BoxConstraints constraints, SurfaceGraph graph) {
    return new ListView.builder(
      itemCount: graph.focusStack.toList().length,
      scrollDirection: Axis.vertical,
      itemExtent: constraints.maxHeight / 3.5,
      itemBuilder: (BuildContext context, int index) {
        Surface s = graph.focusStack.toList().reversed.elementAt(index);
        String arrangement = relName[s.relation.arrangement] ?? 'unknown';
        String dependency = depName[s.relation.dependency] ?? 'unknown';
        return new Row(
          children: <Widget>[
            new Flexible(
              flex: 1,
              child: new Center(
                child: index < graph.focusStack.length - 1
                    ? new Text('Presentation: $arrangement'
                        '\nDependency: $dependency'
                        '\nEmphasis: ${s.relation.emphasis}')
                    : null,
              ),
            ),
            new Flexible(
              flex: 2,
              child: new Container(
                child: new Center(
                  child: new IsoMetric(
                    child: new ChildView(
                        connection: s.connection, hitTestable: false),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => new LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return new Container(
            alignment: FractionalOffset.center,
            width: math.min(constraints.maxWidth, constraints.maxHeight),
            height: constraints.maxHeight,
            padding: const EdgeInsets.symmetric(horizontal: 44.0),
            child: new Scrollbar(
              child: new ScopedModelDescendant<SurfaceGraph>(
                builder:
                    (BuildContext context, Widget child, SurfaceGraph graph) {
                  if (graph.focusStack.isEmpty) {
                    log.warning('focusedSurfaceHistory is empty');
                    return new Container();
                  }
                  return buildGraphList(constraints, graph);
                },
              ),
            ),
          );
        },
      );
}
