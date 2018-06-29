// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'node.dart';
import 'storage_state.dart';

// FleetState stores states of group of instances and associated with them
// StorageStates. It allows to perform modification on one instance, or to
// synchronize states of two instances.
//
// TODO: consider removing dynamic
class FleetState<T extends dynamic> {
  // ignore: unused_field
  int _fleetSize;
  final List<StorageState> _storageStates;
  final List<T> _instances;

  FleetState(int size, T instanceGenerator(int index))
      : _fleetSize = size,
        _storageStates = new List<StorageState>.generate(
            size, (index) => new StorageState(),
            growable: false),
        _instances =
            new List<T>.generate(size, instanceGenerator, growable: false);

  void applyNode(Node cur, int timer) {
    if (cur is ModificationNode) {
      applyModification(cur.instanceId, cur.modification, timer);
    } else if (cur is SynchronizationNode) {
      applySynchronization(cur.instanceId1, cur.instanceId2);
    }
  }

  void applyModification(int id, void Function(T) modification, int time) {
    modification(_instances[id]);
    _storageStates[id].applyChange(_instances[id].getChange(), time);
  }

  void applySynchronization(int id1, int id2) {
    _instances[id1]
        .applyChange(_storageStates[id1].updateWith(_storageStates[id2]));
    _instances[id2]
        .applyChange(_storageStates[id2].updateWith(_storageStates[id1]));
  }
}
