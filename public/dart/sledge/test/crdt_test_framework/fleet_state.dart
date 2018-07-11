// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'package:sledge/src/document/document.dart';

import 'checker.dart';
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
  final List<Checker<T>> _checkers = <Checker<T>>[];

  FleetState(int size, T instanceGenerator(int index))
      : _fleetSize = size,
        _storageStates = new List<StorageState>.generate(
            size, (index) => new StorageState(),
            growable: false),
        _instances =
            new List<T>.generate(size, instanceGenerator, growable: false);

  void applyNode(Node node, int timer) {
    if (node is ModificationNode) {
      applyModification(node.instanceId, node.modification, timer);
    } else if (node is SynchronizationNode) {
      applySynchronization(node.instanceId1, node.instanceId2);
    }

    for (final checker in _checkers) {
      for (final instanceId in node.affectedInstances) {
        checker.check(_instances[instanceId]);
      }
    }
  }

  void addChecker(Checker<T> checker) {
    _checkers.add(checker);
  }

  void applyModification(int id, void Function(T) modification, int time) {
    modification(_instances[id]);
    if (T == Document) {
      // ignore: argument_type_not_assignable
      _storageStates[id].applyChange(Document.getChange(_instances[id]), time);
      // ignore: argument_type_not_assignable
      Document.completeTransaction(_instances[id]);
    } else {
      _storageStates[id].applyChange(_instances[id].getChange(), time);
      _instances[id].completeTransaction();
    }
  }

  void applySynchronization(int id1, int id2) {
    if (T == Document) {
      Document.applyChange(
          // ignore: argument_type_not_assignable
          _instances[id1],
          _storageStates[id1].updateWith(_storageStates[id2]));
      Document.applyChange(
          // ignore: argument_type_not_assignable
          _instances[id2],
          _storageStates[id2].updateWith(_storageStates[id1]));
    } else {
      _instances[id1]
          .applyChange(_storageStates[id1].updateWith(_storageStates[id2]));
      _instances[id2]
          .applyChange(_storageStates[id2].updateWith(_storageStates[id1]));
    }
  }
}
