// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:lib.app.dart/logging.dart';

import '../models/layout_model.dart';
import '../models/surface/positioned_surface.dart';
import '../models/surface/surface.dart';
import '../models/tree.dart';

/// Returns in the order they should stacked
List<PositionedSurface> layoutSurfaces(
  BuildContext context,
  Surface focusedSurface,
  LayoutModel layoutModel,
) {
  final List<PositionedSurface> layout = <PositionedSurface>[];

  // We only execute this layout if containerMembership exists
  String containerId = focusedSurface.properties.containerMembership.last;
  // get the spanning tree of container nodes
  Tree<Surface> spanningTree =
      focusedSurface.containerSpanningTree(containerId);
  Map<String, Surface> nodeMap = <String, Surface>{};
  List<Surface> containerSurfaces =
      spanningTree.map((Tree<Surface> t) => t.value).toList(growable: false);
  for (Surface s in containerSurfaces) {
    nodeMap[s.properties.containerLabel] = s;
  }
  SurfaceContainer container = spanningTree.root.value;
  List<ContainerLayout> layouts = container.layouts;
  ContainerLayout layoutSpec = layouts.first;

  for (LayoutEntry entry in layoutSpec.surfaces) {
    Rect rect = new Rect.fromLTWH(
      entry.rectangle[0],
      entry.rectangle[1],
      entry.rectangle[2],
      entry.rectangle[3],
    );
    String label = entry.nodeName;
    layout.add(
      new PositionedSurface(
        surface: nodeMap[label],
        position: rect,
      ),
    );
  }
  if (layout.isEmpty) {
    log.warning('''Container $containerId with surfaces $containerSurfaces
    could not be laid out. Falling back on focused surface.''');
    layout.add(
      new PositionedSurface(
        surface: focusedSurface,
        position: new Rect.fromLTWH(0.0, 0.0, 1.0, 1.0),
      ),
    );
  }
  return layout;
}
