// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

import 'layout/layout_context.dart';
import 'layout/layout_types.dart';
import 'surface/surface.dart';
import 'tree/surface_tree.dart';

/// The Composer maintains the model of surfaces participating in an experience
/// and their relationships. Using context such as viewport area, surface
/// metadata, etc., it determines a layout given a 'focused' surface.
class Composer {
  /// The set of surfaces that are currently marked as 'hidden' in the
  /// experience - they are still present in the experience, but they will not
  /// be laid out until they have focusSurface() called on them.
  final Set<String> _hiddenSurfaces;

  /// The focus order of surfaces being laid out in the experience. Hiding
  /// removes a surface from the _focusedSurfaces Set and adds it to the
  /// _hiddenSurfaces Set.
  final Set<String> _focusedSurfaces;

  /// The context of the layout
  LayoutContext layoutContext;

  /// The tree recording the relationships between Surfaces in the experience.
  /// All Surfaces are represented here (by surfaceId) including Surfaces with
  /// no current relationships and Surfaces that are currently hidden.
  final SurfaceTree _surfaceTree;

  /// The default LayoutContext
  static const LayoutContext defaultContext =
      const LayoutContext(size: const Size(1280, 800));

  /// Constructor
  Composer({
    this.layoutContext = defaultContext,
  })  : _hiddenSurfaces = Set(),
        _focusedSurfaces = Set(),
        _surfaceTree = new SurfaceTree();

  /// Add a Surface to the tree. [parentId] is an optional paramater used when
  /// this surface has a parent-child relationship with a [Surface] that is
  /// already in the experience - for example if this Surface was launched by
  /// that Surface.
  void addSurface({@required Surface surface, String parentId}) {
    _surfaceTree.add(surface: surface, parentId: parentId);
  }

  /// Destructively remove a Surface from the tree and the focused and hidden
  /// Surface sets: deletes the Surface from the experience. Any children of
  /// the removed Surface are preserved, relationships between those children
  /// and further descendents are also preserved, but any relationship between
  /// those children and ancestors is severed.
  void removeSurface({String surfaceId}) {
    _surfaceTree.remove(surfaceId: surfaceId);
    _focusedSurfaces.remove(surfaceId);
    _hiddenSurfaces.remove(surfaceId);
  }

  /// Brings the Surface with surfaceId into 'focus' - calls to getLayout will
  /// determine a layout starting from this Surface in the tree. The focused
  /// Surface is guaranteed to be shown. The Surface being focused is assumed
  /// to have already been added to the experience.
  void focusSurface({String surfaceId}) {
    // focus is the opposite of hide
    _hiddenSurfaces.remove(surfaceId);
    // bubble the surface to the top of the focus stack
    _focusedSurfaces
      ..remove(surfaceId)
      ..add(surfaceId);
  }

  /// Hides a Surface from the experience. Does not modify the topology of the
  /// tree, just marks one of the nodes as hidden, and does not use it in layout
  void hideSurface({String surfaceId}) {
    _focusedSurfaces.remove(surfaceId);
    _hiddenSurfaces.add(surfaceId);

    // TODO (djmurphy): handle "canHideSurface - dependency considerations"
  }

  /// Update the relationships or metadata for a Surface already in the tree.
  /// If the Surface is not yet in the tree this is a no-op.
  void update({Surface surface, String parentId}) {
    _surfaceTree.update(surface: surface, parentId: parentId);
  }

  /// Determines a layout given the current LayoutContext and focusedSurface, and
  /// returns a list of [Layer]s.
  ///
  /// Each [Layer] in the presentation holds a list of [LayoutElement]s that
  /// make up that Layer.
  ///
  /// The List is ordered from bottom up (as per Flutter Stack convention), so
  /// the upper-most layer of the presentation is the last element in the
  /// returned list.
  ///
  /// If the previousLayout is provided as an argument, it can be taken into
  /// consideration during layout determination. For example, a Presenter
  /// implementation may allow resizing of split points, which might be factored
  /// into subsequent layouts. (Currently unimplemented)
  ///
  /// For a scenario where layout is two layers, with a Single Surface 'C'
  /// occupying the entire back layer, and two Surfaces 'A' and 'B' occupying
  /// the foreground layer, split evenly:
  ///
  ///           XXXXXXXXXXXXXXXXXXXXXX XXXXXXXXXXXXXXXXXXXXXX
  ///          XX                  XX XX                  XX
  ///         XX      XXX         XX XX     XXXXX        XX
  ///        XX     XX  XX       XX XX     XX  XX       XX
  ///       XX    XXXXXXXX      XX XX     XXXXX        XX
  ///      XX    XX    XX      XX XX     XX  XX       XX
  ///     XX    XX    XX      XX XX     XXXXXX       XX
  ///    XXXXXXXXXXXXXXXXXXXXXX XXXXXXXXXXXXXXXXXXXXXX  XXX
  ///        XX                                         XX
  ///       XX                XXXX                     XX
  ///      XX               XX                        XX
  ///     XX               XX                        XX
  ///    XX               XX                        XX
  ///   XX                XXXXX                    XX
  ///  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  ///
  /// Then the returned layout would be (bottom up):
  /// '[
  ///   [
  ///     {"x":0,"y":0,"w":1280,"h":800,"surfaceId":"C"} // SurfaceLayout
  ///   ], // Layer
  ///   [
  ///     {"x":0,"y":0,"w":640,"h":800,"surfaceId":"A"},   // SurfaceLayout
  ///     {"x":640","y":0,"w":640,"h":800,"surfaceId":"B"} // SurfaceLayout
  ///   ] // Layer
  /// ] // List<Layer>'

  List<Layer> getLayout({List<Layer> previousLayout}) {
    // TODO(djmurphy): complete logic - this is placeholder to unblock work
    List<Layer> layout = <Layer>[];
    for (String id in _focusedSurfaces.toList()) {
      layout.add(
        Layer(
          element: SurfaceLayout(
            x: 0,
            y: 0,
            w: layoutContext.size.width,
            h: layoutContext.size.height,
            surfaceId: id,
          ),
        ),
      );
    }
    return layout;
  }
}
