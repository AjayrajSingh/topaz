// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:fidl_fuchsia_ui_viewsv1token/fidl.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:lib.widgets/model.dart';

import '../tree.dart';
import 'surface.dart';
import 'surface_properties.dart';

// Data structure to manage the relationships and relative focus of surfaces
class SurfaceGraph extends Model {
  SurfaceGraph() {
    setupLogger(name: 'Mondrian');
  }

  SurfaceGraph.fromJson(Map<String, dynamic> json) {
    List<dynamic> decodedSurfaceList = json['surfaceList'];
    // for the first item we want to attach it to _tree
    for (dynamic s in decodedSurfaceList) {
      Map<String, dynamic> item = s.cast<String, dynamic>();
      Surface surface = new Surface.fromJson(item, this);
      _surfaces[surface.node.value] = surface;
    }
    _surfaces.forEach((String id, Surface surface) {
      Tree<String> node = surface.node;
      if (surface.isParentRoot) {
        _tree.add(node);
      }
      if (surface.childIds != null) {
        for (String id in surface.childIds) {
          node.add(_surfaces[id].node);
        }
      }
    });
    dynamic list = json['focusStack'];
    List<String> focusStack = list.cast<String>();
    _focusedSurfaces.addAll(focusStack);
  }

  /// Cache of surfaces
  final Map<String, Surface> _surfaces = <String, Surface>{};

  /// Surface relationship tree
  final Tree<String> _tree = new Tree<String>(value: null);

  /// The stack of previous focusedSurfaces, most focused at end
  final List<String> _focusedSurfaces = <String>[];

  /// The stack of previous focusedSurfaces, most focused at end
  final Set<String> _dismissedSurfaces = new Set<String>();

  /// A mapping between surfaces that were brought in as ModuleSource::External
  /// surfaces (e.g. suggestions) and surfaces that were visually present at
  /// their introduction, in order to track where to provide a shell affordance
  /// for resummoning external surfaces that have been dismissed
  /// (surfaces are identified by ID)
  final Map<String, String> _visualAssociation = <String, String>{};

  /// The node corresponding to the given id.
  Surface getNode(String id) => _surfaces[id];

  /// The last focused surface.
  Surface _lastFocusedSurface;

  /// The currently most focused [Surface]
  Surface get focused =>
      _focusedSurfaces.isEmpty ? null : _surfaces[_focusedSurfaces.last];

  /// The history of focused [Surface]s
  Iterable<Surface> get focusStack => _focusedSurfaces
      .where(_surfaces.containsKey)
      .map((String id) => _surfaces[id]);

  /// Add a [Surface] to the graph with the given parameters.
  ///
  /// Returns the surface that was added to the graph.
  Surface addSurface(
    String id,
    SurfaceProperties properties,
    String parentId,
    SurfaceRelation relation,
    String pattern,
  ) {
    Tree<String> node = _tree.find(id) ?? new Tree<String>(value: id);
    Tree<String> parent =
        (parentId == kNoParent) ? _tree : _tree.find(parentId);
    assert(parent != null);
    assert(relation != null);
    parent.add(node);
    Surface oldSurface = _surfaces[id];
    Surface updatedSurface =
        new Surface(this, node, properties, relation, pattern);
    _surfaces[id] = updatedSurface;
    // if this is an external surface, create an association between this and
    // the most focused surface.
    if (properties.source == ModuleSource.external$) {
      _visualAssociation[_focusedSurfaces.last] = id;
    }
    oldSurface?.notifyListeners();
    notifyListeners();
    return updatedSurface;
  }

  /// Removes [Surface] from graph
  void removeSurface(String id) {
    // TODO(alangardner): Remap edges to transitive nodes appropriately
    if (_surfaces.keys.contains(id)) {
      Tree<String> node = _tree.find(id);
      Tree<String> parent = node.parent;
      node.detach();
      node.children.forEach(parent.add);
      _focusedSurfaces.remove(id);
      _dismissedSurfaces.remove(id);
      _surfaces.remove(id);
      notifyListeners();
    }
  }

  /// Move the surface up in the focus stack, undismissing it if needed.
  ///
  /// If relativeId is null, the surface is re-inserted  at the top of the stack
  /// If relativeId is provided, the surface is re-inserted at the higher of
  /// above the relative surface or any of its direct children, or its original
  /// position.
  void focusSurface(String id, String relativeId) {
    if (!_surfaces.containsKey(id)) {
      log.warning('Invalid surface id "$id"');
      return;
    }
    int currentIndex = _focusedSurfaces.indexOf(id);
    _dismissedSurfaces.remove(id);
    _focusedSurfaces.remove(id);
    if (relativeId == null || relativeId == kNoParent) {
      _focusedSurfaces.add(id);
    } else {
      int relativeIndex = -1;
      final Tree<String> relative = _tree.find(relativeId);
      if (relative != null) {
        relativeIndex = _focusedSurfaces.indexOf(relative.value);
        // Use the highest index of relative or its children
        for (Tree<String> childNode in relative.children) {
          String childId = childNode.value;
          relativeIndex =
              math.max(relativeIndex, _focusedSurfaces.indexOf(childId));
        }
        // If none of those are focused, find the closest ancestor that is focused
        Tree<String> ancestor = relative.parent;
        while (relativeIndex < 0 && ancestor.value != null) {
          relativeIndex = _focusedSurfaces.indexOf(ancestor.value);
          ancestor = ancestor.parent;
        }
      }
      // Insert to the highest of one past relative index, or the original index
      int index =
          math.max(relativeIndex < 0 ? -1 : relativeIndex + 1, currentIndex);
      if (index >= 0) {
        _focusedSurfaces.insert(index, id);
      }
    }

    // Also request the input focus through the child view connection.
    _surfaces[id].connection.requestFocus();
    _lastFocusedSurface = _surfaces[id];

    notifyListeners();
  }

  /// Add a container root to the surface graph
  void addContainer(
    String id,
    SurfaceProperties properties,
    String parentId,
    SurfaceRelation relation,
    List<ContainerLayout> layouts,
  ) {
    // TODO (djurphy): collisions/pathing - partial fix if we
    // make the changes so container IDs are paths.
    log.info('addContainer: $id');
    Tree<String> node = _tree.find(id) ?? new Tree<String>(value: id);
    log.info('found or made node: $node');
    Tree<String> parent =
        (parentId == kNoParent) ? _tree : _tree.find(parentId);
    assert(parent != null);
    assert(relation != null);
    parent.add(node);
    Surface oldSurface = _surfaces[id];
    _surfaces[id] = new SurfaceContainer(
        this, node, properties, relation, '' /*pattern*/, layouts);
    oldSurface?.notifyListeners();
    log.info('_surfaces[id]: ${_surfaces[id]}');
    notifyListeners();
  }

  /// Returns the list of surfaces that would be dismissed if this surface
  /// were dismissed - e.g. as a result of dependency - including this surface
  List<String> dismissedSet(String id) {
    Surface dismissed = _surfaces[id];
    List<Surface> ancestors = dismissed.ancestors.toList();
    List<Surface> dependentTree = dismissed.dependentSpanningTree
        .map((Tree<Surface> t) => t.value)
        .toList()
          // TODO(djmurphy) - when codependent comes in this needs to change
          // this only removes down the tree, codependents would remove their
          // ancestors
          ..removeWhere((Surface s) => ancestors.contains(s));
    List<String> depIds =
        dependentTree.map((Surface s) => s.node.value).toList();
    return depIds;
  }

  /// Check if given surface can be dismissed
  bool canDismissSurface(String id) {
    List<String> wouldDismiss = dismissedSet(id);
    return _focusedSurfaces
        .where((String fid) => !wouldDismiss.contains(fid))
        .isNotEmpty;
  }

  /// When called surface is no longer displayed
  bool dismissSurface(String id) {
    if (!canDismissSurface(id)) {
      return false;
    }
    List<String> depIds = dismissedSet(id);
    _focusedSurfaces.removeWhere((String fid) => depIds.contains(fid));
    _dismissedSurfaces.addAll(depIds);
    notifyListeners();
    return true;
  }

  /// True if surface has been dismissed and not subsequently focused
  bool isDismissed(String id) => _dismissedSurfaces.contains(id);

  /// Used to update a [Surface] with a live ChildViewConnection
  void connectView(String id, InterfaceHandle<ViewOwner> viewOwner) {
    final Surface surface = _surfaces[id];
    if (surface != null) {
      log.fine('connectView $surface');
      surface
        ..connection = new ChildViewConnection(
          viewOwner,
          onAvailable: (ChildViewConnection connection) {
            trace('surface $id available');

            // If this surface is the last focused one, also request input focus
            if (_lastFocusedSurface == surface) {
              connection.requestFocus();
            }

            surface.notifyListeners();
          },
          onUnavailable: (ChildViewConnection connection) {
            trace('surface $id unavailable');
            surface.connection = null;
            if (_surfaces.containsValue(surface)) {
              removeSurface(id);
              notifyListeners();
            }
            // Also any existing listener
            surface.notifyListeners();
          },
        )
        ..notifyListeners();
    }
  }

  // Get the SurfaceIds of associated external surfaces
  // (surfaces originating from outside the current story)
  // that are dismissed and associated with the current Surface
  Set<String> externalSurfaces({String surfaceId}) {
    // Case1: An external child has a relationship with this surface
    // and the child has been dismissed
    Surface parent = getNode(surfaceId);
    List<Surface> externalSurfaces = parent.children.toList()
      ..retainWhere(
          (Surface s) => s.properties.source == ModuleSource.external$);
    Set<String> externalIds =
        externalSurfaces.map((Surface s) => s.node.value).toSet();
    // Case2: The focused surface has a recorded visual association with an
    // external surface
    if (_visualAssociation[surfaceId].isNotEmpty) {
      externalIds.add(_visualAssociation[surfaceId]);
    }
    return externalIds;
  }

  /// Returns the amount of [Surface]s in the graph
  int get size => _surfaces.length;

  @override
  String toString() => 'Tree:\n${_tree.children.map(_toString).join('\n')}';

  String _toString(Tree<String> node, {String prefix = ''}) {
    String nodeString = '$prefix${_surfaces[node.value]}';
    if (node.children.isNotEmpty) {
      nodeString =
          '$nodeString\n${node.children.map((Tree<String> node) => _toString(node, prefix: '$prefix  ')).join('\n')}';
    }
    return '$nodeString';
  }

  Map<String, dynamic> toJson() {
    return {
      'surfaceList': _surfaces.values.toList(),
      'focusStack': _focusedSurfaces,
      'links': [], // TODO(jphsiao): plumb through link data
    };
  }
}
