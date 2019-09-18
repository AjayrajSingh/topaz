// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia_vfs/vfs.dart' as vfs;

import '../../vmo/vmo_writer.dart';
import '../inspect.dart';

/// A concrete implementation of the [Inspect] interface.
///
/// This class is not intended to be used directly by authors but instead
/// should be used by the [Inspect] factory constructor.
class InspectImpl implements Inspect {
  Node _root;

  /// The default constructor for this instance.
  InspectImpl(vfs.PseudoDir directory, String fileName, VmoWriter writer) {
    directory.addNode(fileName, writer.vmoNode);

    _root = RootNode(writer);
  }

  @override
  Node get root => _root;
}
