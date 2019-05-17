// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Enum defining the presentation patterns affecting Surface arrangement in
/// Stories that can be expressed in Surface relationships.
///
/// These relationships are usually defined at runtime addition of a Surface
/// to the experience and defined by the parent e.g. as part of an intent.
enum SurfaceArrangement {
  /// none: no relationship specified
  none,

  /// copresent: parent expresses desire to be shown with child
  copresent,

  /// sequential: parent expresses desire to not be shown with child
  sequential,

  /// onTop: parent expresses desire for child to stack on top of it, inheriting
  /// the box layout allocated to the parent.
  onTop,
}

/// Enum defining the lifecycle dependency affecting Surfaces
/// in Stories that can be expressed in Surface Relationships
enum SurfaceDependency {
  /// none: Surfaces are independent
  none,

  /// dependent: the child's lifecycle is tied to the parent
  dependent,
}

/// Multidimensional relation between Surfaces
class SurfaceRelation {
  /// The arrangement component of the relationship
  final SurfaceArrangement arrangement;

  /// The dependency component of the relationship
  final SurfaceDependency dependency;

  /// The 'emphasis' between nodes - the relative weight between parent and
  /// child: emphasis < 1.0 results in a smaller child and vice-versa.
  /// The default, 1.0 results in the same sized child as parent.
  final double emphasis;

  /// Define a relationship between two surfaces
  const SurfaceRelation({
    this.arrangement = SurfaceArrangement.none,
    this.dependency = SurfaceDependency.none,
    this.emphasis = 1.0,
  });
}
