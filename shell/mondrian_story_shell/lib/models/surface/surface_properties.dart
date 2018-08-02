// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Inherent properties of a surface
class SurfaceProperties {
  /// Const constructor
  SurfaceProperties({this.containerLabel});

  SurfaceProperties.fromJson(Map<String, dynamic> json) {
    containerLabel = json['containerLabel'];
    containerMembership = json['containerMembership'];
  }

  /// Belongs to a container with label containerLabel
  String containerLabel;

  /// List of the containers this Surface is a member of
  /// (To be able to support container-to-container transitions)
  /// The container this Surface is currently participating in is
  /// end of list. If this Surface is focused, that is the container that
  /// will be laid out.
  List<String> containerMembership;

  Map<String, dynamic> toJson() => {
        'containerLabel': containerLabel,
        'containerMembership': containerMembership,
      };
}
