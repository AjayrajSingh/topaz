// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:lib.widgets/model.dart';

import '../models/surface/surface.dart';
import '../models/surface/surface_graph.dart';

import 'surface_resize.dart';

/// Debug Flag
const bool _storytellerDebug = true;

/// Size/Padding/Margin related constants
const double _labelWidgetHeight = 30.0;
const double _labelHorizontalPadding = 24.0;
const double _pageHorizontalPadding = 28.0;
const double _pageTopPadding = 28.0;
const double _branchWidth = 160.0;
const double _branchPadding = 48.0;
const double _surfaceWidgetWidth = 150.0;
const double _surfaceWidgetHeight = 100.0;
const double _surfaceWidgetTextHeight = 30.0;
const double _relationshipWidgetWidth = 120.0;
const double _relationshipWidgetHeight = 60.0;
const double _relationshipTreeFontSize = 10.0;
const FontWeight _relationshipTreeFontWeight = FontWeight.w200;
const double _iconSize = 12.0;

const Color _storytellerPrimaryColor = const Color(0xFF6315F6);

/// Printable names for relation arrangement
const Map<SurfaceArrangement, String> relName =
    const <SurfaceArrangement, String>{
  SurfaceArrangement.none: 'None',
  SurfaceArrangement.copresent: 'Co-present',
  SurfaceArrangement.sequential: 'Sequential',
  SurfaceArrangement.ontop: 'Ontop',
};

/// Printable names for relation dependency
const Map<SurfaceDependency, String> depName =
    const <SurfaceDependency, String>{
  SurfaceDependency.dependent: 'Dependent',
  SurfaceDependency.none: 'Independent',
};

/// A tree graph that shows the surface relationships (StoryTeller).
///
/// Shows the depth of the tree, presentational relationships, dependencies,
/// and emphasis between parent and child surfaces.
/// Also shows the state of each surface via [_buildStateIndicator].
class SurfaceRelationships extends StatelessWidget {
  /// Constructor
  const SurfaceRelationships({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) => new LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return new Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            color: Colors.grey[100],
            child: new ScopedModelDescendant<SurfaceGraph>(
              builder:
                  (BuildContext context, Widget child, SurfaceGraph graph) {
                if (graph.focusStack.isEmpty) {
                  log.warning('focusedSurfaceHistory is empty');
                  return new Container();
                }
                return _buildRelationshipsPage(context, constraints, graph);
              },
            ),
          );
        },
      );

  Widget _buildRelationshipsPage(
      BuildContext context, BoxConstraints constraints, SurfaceGraph graph) {
    Map<String, GlobalKey> surfaceKeys = <String, GlobalKey>{};
    GlobalKey stackKey = new GlobalKey();
    Set<Surface> firstDepthSurfaces = new Set<Surface>();

    for (Surface s in graph.focusStack.toList()) {
      firstDepthSurfaces.add(s.root);
    }

    int maxHeight = 0;
    for (Surface s in firstDepthSurfaces) {
      if (s.node.height > maxHeight) {
        maxHeight = s.node.height;
      }
    }

    if (_storytellerDebug) {
      log.info('*** The height of the StoryGraph is $maxHeight');
    }

    double totalLabelWidth = _pageHorizontalPadding * 2 +
        _surfaceWidgetWidth +
        (_surfaceWidgetWidth + _branchWidth) * (maxHeight);

    if (totalLabelWidth < MediaQuery.of(context).size.width) {
      totalLabelWidth = MediaQuery.of(context).size.width;
    }

    return new SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: new Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildLabel(totalLabelWidth, maxHeight),
          _buildContent(graph, stackKey, surfaceKeys, firstDepthSurfaces),
        ],
      ),
    );
  }

  Widget _buildLabel(double labelWidth, int maxHeight) {
    return new Material(
      elevation: 4.0,
      child: new Container(
        width: labelWidth,
        child: new Row(
          children: _buildLabelWidgetList(maxHeight),
        ),
      ),
    );
  }

  Widget _buildContent(SurfaceGraph graph, GlobalKey stackKey,
      Map<String, GlobalKey> surfaceKeys, Set<Surface> firstSurfaces) {
    return new Expanded(
      child: new SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: new Stack(
          key: stackKey,
          children: <Widget>[
            _buildEdges(stackKey, surfaceKeys, firstSurfaces),
            _buildNodes(graph, surfaceKeys, firstSurfaces),
          ],
        ),
      ),
    );
  }

  Widget _buildEdges(GlobalKey stackKey, Map<String, GlobalKey> surfaceKeys,
      Set<Surface> firstSurfaces) {
    return new CustomPaint(
      painter: new _RelationshipTreeEdges(
        firstSurfaces: firstSurfaces,
        surfaceKeys: surfaceKeys,
        backgroundKey: stackKey,
      ),
    );
  }

  Widget _buildNodes(SurfaceGraph graph, Map<String, GlobalKey> surfaceKeys,
      Set<Surface> firstSurfaces) {
    return new Container(
      padding: new EdgeInsets.only(
        left: _pageHorizontalPadding,
        right: _pageHorizontalPadding,
        top: _pageTopPadding,
      ),
      child: new Column(
        children: firstSurfaces
            .map((surface) => _buildTree(surfaceKeys, graph, surface,
                (graph.focusStack.last == surface)))
            .toList(),
      ),
    );
  }

  /// Builds the labels that shows the depth of each column.
  List<Widget> _buildLabelWidgetList(int maxHeight) {
    List<Widget> labelWidgets = <Widget>[];
    double totalLength = _pageHorizontalPadding + _surfaceWidgetWidth;
    labelWidgets.add(new Container(
      /// Depth 1
      padding: new EdgeInsets.only(right: _labelHorizontalPadding),
      width: totalLength,
      height: _labelWidgetHeight,
      decoration: _labelBoxDecoration(true, true),
      alignment: Alignment.centerRight,
      child: new Text(
        'Depth 1',
        style: new TextStyle(
          color: Colors.black,
          fontSize: 10.0,
        ),
      ),
    ));

    double labelWidgetWidth = _surfaceWidgetWidth + _branchWidth;

    // Other labels: Depth 2 ~
    for (int i = 0; i < maxHeight; i++) {
      totalLength += labelWidgetWidth;

      labelWidgets.add(new Container(
        padding: new EdgeInsets.only(right: _labelHorizontalPadding),
        width: labelWidgetWidth,
        height: _labelWidgetHeight,
        decoration: _labelBoxDecoration(true, true),
        alignment: Alignment.centerRight,
        child: new Text(
          'Depth ${i+2}',
          style: new TextStyle(
            color: Colors.black,
            fontSize: 10.0,
          ),
        ),
      ));
    }

    labelWidgets.add(new Expanded(
      child: new Container(
        height: _labelWidgetHeight,
        decoration: _labelBoxDecoration(false, true),
      ),
    ));

    return labelWidgets;
  }

  BoxDecoration _labelBoxDecoration(bool rightBorder, bool bottomBorder) {
    return new BoxDecoration(
      color: Colors.white,
      border: new Border(
        right: new BorderSide(
          color: rightBorder ? Colors.grey[400] : Colors.transparent,
          width: 0.5,
        ),
        bottom: new BorderSide(
          color: bottomBorder ? Colors.grey[400] : Colors.transparent,
          width: 0.5,
        ),
      ),
    );
  }

  /// Builds the surface relationship tree recursively.
  ///
  /// The tree's depth grows horizontally.
  /// The sibling nodes are added vertically.
  Widget _buildTree(Map<String, GlobalKey> globalKeys, SurfaceGraph graph,
      Surface surface, bool isFocused) {
    if (_storytellerDebug) {
      if (graph == null) {
        log.shout('*** The storyGraph is null!');
      }
      if (surface == null) {
        log.shout('*** The current surface is null!');
      }
    }

    assert(graph != null);
    assert(surface != null);

    if (_storytellerDebug) {
      log
        ..info('*** This surface ID: ${surface.node.value}')
        ..info('*** This surface\'s parentId: ${surface.parentId}')
        ..info(
            '*** The length of the focus stack: ${graph.focusStack.toList().length}');
    }

    String id = surface.node.value;
    globalKeys[id] = new GlobalKey();

    Widget thisWidget = _buildChildNode(globalKeys[id], surface, isFocused);

    List<Surface> children = new List<Surface>.from(surface.children.toList())
      ..removeWhere((child) => child == null);

    if (_storytellerDebug) {
      log.info(
          '*** BUILDING TREE... surface($id)\'s global key = ${globalKeys[id]}');
    }

    if (_storytellerDebug) {
      log.info('*** The number of children of surface $id: ${children.length}');
    }

    if (children.isEmpty) {
      return thisWidget;
    } else {
      if (_storytellerDebug) {
        log.info('*** The first child: ${children[0]}');
      }
      return new Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          thisWidget,
          (children.length == 1)
              ? _buildTree(globalKeys, graph, children[0],
                  (graph.focusStack.toList().last == children[0]))
              : new Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children.map((child) {
                    return _buildTree(globalKeys, graph, child,
                        (graph.focusStack.toList().last == child));
                  }).toList(),
                ),
        ],
      );
    }
  }

  /// Returns a container containing a relationship widget and a surface widget
  Widget _buildChildNode(GlobalKey key, Surface surface, bool isFocused) {
    bool isFirstDepthNode = (surface.parentId == null);

    return new Container(
      padding: new EdgeInsets.only(bottom: _branchPadding),
      child: new Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          (isFirstDepthNode)
              ? new Container()
              : _buildRelationshipWidget(surface),
          _buildSurfaceWidget(key, surface, isFocused),
        ],
      ),
    );
  }

  /// Builds a branch tag of the tree that shows the relationship between
  /// a surface and its parent.
  ///
  /// This tag appears on a branch between two surfaces.
  Widget _buildRelationshipWidget(Surface surface) {
    String presentation = relName[surface.relation.arrangement] ?? 'Unknown';
    String dependency = depName[surface.relation.dependency] ?? 'Unknown';
    String emphasis = surface.relation.emphasis.toStringAsPrecision(2);

    return new Container(
      width: _branchWidth,
      height: _surfaceWidgetHeight,
      child: new Center(
        child: new Container(
          padding: new EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          width: _relationshipWidgetWidth,
          height: _relationshipWidgetHeight,
          decoration: _relationshipBoxDeco(dependency),
          child: new Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildRelationshipRow(Icons.filter, presentation, dependency),
              _buildRelationshipRow(Icons.link, dependency, dependency),
              _buildRelationshipRow(Icons.data_usage, emphasis, dependency),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRelationshipRow(IconData icon, String text, String dependency) {
    return new Row(
      children: <Widget>[
        _relationshipIcon(icon, dependency),
        new Container(
          padding: new EdgeInsets.only(left: 10.0),
          child: new Text(
            text,
            style: _relationshipTextStyle(dependency),
          ),
        ),
      ],
    );
  }

  BoxDecoration _relationshipBoxDeco(String dependency) {
    return new BoxDecoration(
      color: (dependency == 'Independent')
          ? Colors.white
          : _storytellerPrimaryColor,
      borderRadius: BorderRadius.circular(10.0),
      border: new Border.all(
        color: _storytellerPrimaryColor,
        width: 2.0,
      ),
    );
  }

  TextStyle _relationshipTextStyle(String dependency) {
    return new TextStyle(
      color: (dependency == 'Independent')
          ? _storytellerPrimaryColor
          : Colors.white,
      fontSize: _relationshipTreeFontSize,
      fontWeight: _relationshipTreeFontWeight,
    );
  }

  Icon _relationshipIcon(IconData icon, String dependency) {
    return new Icon(
      icon,
      color: (dependency == 'Independent')
          ? _storytellerPrimaryColor
          : Colors.white,
      size: _iconSize,
    );
  }

  /// Builds a node of the tree that shows a surface, the surface's id and state.
  Widget _buildSurfaceWidget(GlobalKey key, Surface surface, bool isFocused) {
    return new Container(
      height: _surfaceWidgetHeight + _surfaceWidgetTextHeight + 8.0,
      child: new Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _buildSurfaceImage(key, surface),
          _buildSurfaceInfoText(surface, isFocused),
        ],
      ),
    );
  }

  Widget _buildSurfaceImage(GlobalKey key, Surface surface) {
    return new Material(
      key: key,
      color: Colors.white,
      elevation: 2.0,
      borderRadius: new BorderRadius.circular(8.0),
      child: new Container(
        width: _surfaceWidgetWidth,
        height: _surfaceWidgetHeight,
        child: new Center(
          child: new SurfaceResize(
            child: new ChildView(
              connection: surface.connection,
              hitTestable: false,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSurfaceInfoText(Surface surface, bool isFocused) {
    return new Container(
      width: _surfaceWidgetWidth,
      height: _surfaceWidgetTextHeight,
      child: new Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildStateIndicator(surface.dismissed, isFocused),
          new Expanded(
            child: new Text(
              '${surface.node.value}',
              style: TextStyle(
                color: (surface.dismissed) ? Colors.grey[400] : Colors.black,
                fontSize: _relationshipTreeFontSize,
                fontWeight: _relationshipTreeFontWeight,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }

  /// Shows the state of a surface.
  ///
  /// Focused: A violet circle.
  /// Active: A white circle with violet border.
  /// Dismissed: A grey circle.
  Widget _buildStateIndicator(bool isDismissed, bool isFocused) {
    Color stateFillColor;
    Color stateBorderColor;
    if (isDismissed) {
      stateFillColor = Colors.grey[400];
      stateBorderColor = Colors.grey[400];
    } else if (isFocused) {
      stateFillColor = _storytellerPrimaryColor;
      stateBorderColor = _storytellerPrimaryColor;
    } else {
      stateFillColor = Colors.white;
      stateBorderColor = _storytellerPrimaryColor;
    }

    return new Padding(
      padding: const EdgeInsets.only(top: 4.0, left: 8.0, right: 8.0),
      child: new Container(
        width: 6.0,
        height: 6.0,
        decoration: new BoxDecoration(
          color: stateFillColor,
          borderRadius: BorderRadius.circular(3.0),
          border: new Border.all(
            width: 1.0,
            color: stateBorderColor,
          ),
        ),
      ),
    );
  }
}

/// The edge lines between parent and child surfaces.
///
/// The position of an edge is decided by the positions of the surface widget.
class _RelationshipTreeEdges extends CustomPainter {
  final Set<Surface> firstSurfaces;
  final Map<String, GlobalKey> surfaceKeys;
  final GlobalKey backgroundKey;

  _RelationshipTreeEdges(
      {@required this.firstSurfaces,
      @required this.surfaceKeys,
      @required this.backgroundKey});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = new Paint()
      ..color = _storytellerPrimaryColor
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final bgContext = backgroundKey.currentContext;
    final RenderBox bgBox = bgContext.findRenderObject();

    Set<Surface> currentSurfaces = new Set<Surface>.from(firstSurfaces);

    while (currentSurfaces.isNotEmpty) {
      for (Surface surface in currentSurfaces) {
        double startX;
        double endX;
        double minY;
        double maxY;

        // Draws horizontal edges
        for (int i = 0; i < surface.children.length; i++) {
          String childId = surface.children.toList()[i].node.value;
          final childSurfaceContext = surfaceKeys[childId].currentContext;
          final RenderBox childSurfaceBox =
              childSurfaceContext.findRenderObject();
          final childSurfaceGlobalPos =
              childSurfaceBox.localToGlobal(Offset(0.0, 0.0));

          final childSurfacePos = bgBox.globalToLocal(childSurfaceGlobalPos);

          if (_storytellerDebug) {
            log
              ..info('*** x: ${childSurfacePos.dx}')
              ..info('*** y: ${childSurfacePos.dy}');
          }

          double y = childSurfacePos.dy + (childSurfaceBox.size.height / 2);

          if (i == 0) {
            startX = childSurfacePos.dx - _branchWidth;
            endX = childSurfacePos.dx;
            minY = y;
          } else if (i == 1) {
            startX += (_branchWidth - _relationshipWidgetWidth) / 4;
          }

          maxY = y;

          canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
        }

        // Draws a vertical edge
        if (surface.children.length > 1) {
          canvas.drawLine(Offset(startX, minY), Offset(startX, maxY), paint);
        }
      }

      Set<Surface> nextSurfaces = new Set<Surface>();
      for (Surface s in currentSurfaces) {
        for (int i = 0; i < s.children.length; i++) {
          nextSurfaces.add(s.children.toList()[i]);
        }
      }
      currentSurfaces = nextSurfaces;
    }
  }

  @override
  bool shouldRepaint(_RelationshipTreeEdges oldDelegate) {
    return false;
  }
}
