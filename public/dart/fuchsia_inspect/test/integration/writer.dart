// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:typed_data';

import 'package:fuchsia_inspect/src/vmo/vmo_writer.dart';
import 'package:fuchsia_inspect/src/vmo/vmo_holder.dart';
import 'package:fuchsia_services/services.dart';
import 'package:fuchsia_vfs/vfs.dart';

const String value = 'value';

int _uniqueValue = 0;

String uniqueName(String prefix) =>
    '${prefix}0x${(_uniqueValue++).toRadixString(16)}';

/// This example program exposes an Inspect VMO tree consisting of
/// [Table] nodes that can contain an arbitrary number of [Item] nodes.

/// [Item]s are stored in [Table]s. This is an example of a child node
/// with a parent.
class Item {
  final VmoWriter _writer;
  final int _parent;
  int _value;

  /// Constructs an Item.
  Item(this._writer, this._parent, String name) {
    var item = _writer.createNode(_parent, name);
    _value = _writer.createMetric(item, 'value', 0);
  }

  /// Adds [value] to the [Item]'s metric.
  void add(int value) => _writer.addMetric(_value, value);
}

/// [Table]s can contain [Items]. This is an example of a parent
/// containing children.
class Table {
  final VmoWriter _writer;
  final int _parent;
  final List<Item> _items = [];
  final int _table;

  /// Constructs a [Table].
  Table(this._writer, this._parent, String name)
      : _table = _writer.createNode(_parent, name) {
    var version = _writer.createProperty(_table, 'version');
    var frame = _writer.createProperty(_table, 'frame');
    _writer
      ..createMetric(_table, 'value', -10)
      ..setProperty(frame, ByteData(3))
      ..setProperty(version, '1.0');
  }

  /// Adds an [Item] with value [value] to the [Table].
  Item newItem(int value) {
    var item = Item(_writer, _table, uniqueName('item-'))..add(value);
    _items.add(item);
    return item;
  }
}

void main(List<String> args) {
  var vmo = VmoHolder(4096);
  var writer = VmoWriter(vmo);
  var t1 = Table(writer, writer.rootNode, 't1');
  var t2 = Table(writer, writer.rootNode, 't2');

  t1.newItem(10);
  t1.newItem(90).add(10);
  t2.newItem(2).add(2);

  final context = StartupContext.fromStartupInfo();
  final vnode = VmoFile.readOnly(vmo.vmo, VmoSharingMode.shareDuplicate);
  context.outgoing.debugDir().addNode('root.inspect', vnode);
}
