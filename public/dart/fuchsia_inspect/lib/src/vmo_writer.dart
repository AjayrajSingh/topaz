// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'vmo_heap.dart';

/// Opaque information referring to a Value (Property, Metric, Node) stored in the VMO.
///
/// The user of this API should not care about what's in InspectHandle - just hold it
/// and pass it back to VmoWriter for further operations on the Value referred to by the handle.
class InspectHandle {
  /// First opaque number.
  int opaque1;

  /// Second opaque number.
  int opaque2;

  /// Constructor
  InspectHandle(this.opaque1, this.opaque2);
}

/// An Inspect-format VMO with accessors.
///
/// This holds a VMO, writes Nodes, Metrics, and Properties to
/// the VMO, modifies them, and deletes them.
class VmoWriter {
  final VmoHeap _vmo;

  /// Constructor.
  ///
  /// maxSize should be >= 32 bytes and will be rounded up to a multiple of 4K.
  VmoWriter(int maxSizeBytes) : _vmo = VmoHeap(maxSizeBytes, maxSizeBytes);

  // All the implementations here are trivially wrong placeholders.
  // For now, just look at the method signature.

  /// Gets the top Node of the Inspect tree.
  InspectHandle get rootNode => InspectHandle(1, 2);

  /// Creates a new Node inside the tree.
  InspectHandle createNode(InspectHandle parent, String name) {
    return parent;
  }

  /// Frees the Node.
  void freeNode(InspectHandle node) {
    _vmo.writeInt64(node.opaque1, 0);
  }

  /// Adds a named Property to an node.
  InspectHandle createProperty(InspectHandle parentNode, ByteData name) {
    _vmo.write(parentNode.opaque1, name);
    return parentNode;
  }

  /// Sets a Property's value.
  void setProperty(InspectHandle property, ByteData value) {
    _vmo.write(property.opaque1, value);
  }

  /// Deletes a Property.
  void freeProperty(InspectHandle property) {
    _vmo.writeInt64(property.opaque1, 0);
  }

  // TODO(cphoenix): Convert to generic for Int and Double (not Uint).

  /// Creates and assigns value.
  InspectHandle createIntMetric(
      InspectHandle parentNode, String name, int value) {
    _vmo.writeInt64(parentNode.opaque1, value);
    return parentNode;
  }

  /// Sets the metric's value.
  void setIntMetric(InspectHandle metric, int value) {
    _vmo.writeInt64(metric.opaque1, value);
  }

  /// Adds to existing value.
  void addIntMetric(InspectHandle metric, int value) {
    _vmo.writeInt64(metric.opaque1, value);
  }

  /// Subtracts from existing value.
  void subtractIntMetric(InspectHandle metric, int value) {
    _vmo.writeInt64(metric.opaque1, value);
  }

  /// Deletes the Metric.
  void freeIntMetric(InspectHandle metric) {
    _vmo.writeInt64(metric.opaque1, 0);
  }
}
