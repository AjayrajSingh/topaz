// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'package:fuchsia_inspect/inspect.dart';
import 'package:fuchsia_inspect/src/inspect/internal/_inspect_impl.dart';
import 'package:fuchsia_inspect/src/vmo/util.dart';
import 'package:fuchsia_inspect/src/vmo/vmo_holder.dart';
import 'package:fuchsia_inspect/src/vmo/vmo_writer.dart';
import 'package:fuchsia_services/services.dart';
import 'package:test/test.dart';

import '../util.dart';

void main() {
  VmoHolder vmo;
  Node root;

  setUp(() {
    var context = StartupContext.fromStartupInfo();
    vmo = FakeVmo(512);
    var writer = VmoWriter(vmo);
    Inspect inspect = InspectImpl(context, writer);
    root = inspect.root;
  });

  test('Child nodes have unique indices from their parents', () {
    var childNode = root.child('banana');

    expect(childNode, isNotNull);
    expect(childNode.index, isNot(root.index));
  });

  test('Child nodes created twice return the same object', () {
    var childNode = root.child('banana');
    var childNode2 = root.child('banana');

    expect(childNode, isNotNull);
    expect(childNode2, isNotNull);
    expect(childNode, same(childNode2));
  });

  test('Nodes created after deletion return different objects', () {
    var childNode = root.child('banana')..delete();
    var childNode2 = root.child('banana');

    expect(childNode, isNotNull);
    expect(childNode2, isNotNull);
    expect(childNode, isNot(childNode2));
  });

  test('Child nodes have unique indices from their siblings', () {
    var child1 = root.child('thing1');
    var child2 = root.child('thing2');

    expect(child1.index, isNot(child2.index));
  });

  test('Deleting root node has no effect', () {
    root.delete();
    var child = root.child('sheep');
    expect(() => readNameIndex(vmo, child), returnsNormally);
  });

  group('Deleted node tests:', () {
    Node deletedNode;

    setUp(() {
      deletedNode = root.child('sheep')..delete();
    });

    test('can be deleted (more than once)', () {
      var child = deletedNode.child('sheep')..delete();
      expect(() => readNameIndex(vmo, deletedNode), throwsA(anything),
          reason: 'cannot read VMO values from a deleted node');
      expect(() => deletedNode.delete(), returnsNormally);
      expect(() => readNameIndex(vmo, child), throwsA(anything),
          reason: 'cannot read VMO values from a deleted node');
      expect(() => child.delete(), returnsNormally);
    });

    test('Creating a child on an already deleted node is a no-op', () {
      Node grandchild;
      expect(() => grandchild = deletedNode.child('404'), returnsNormally);
      expect(() => grandchild.child('404'), returnsNormally);
      expect(() => readNameIndex(vmo, grandchild), throwsA(anything),
          reason: 'cannot read VMO values from a deleted node');
    });

    test('Creating an IntProperty on an already deleted node is a no-op', () {
      IntProperty property;
      expect(() => property = deletedNode.intProperty('404'), returnsNormally);
      expect(() => property.setValue(404), returnsNormally);
      expect(() => readInt(vmo, property), throwsA(anything),
          reason: 'cannot read VMO values from a deleted node');
    });

    test('Creating a DoubleProperty on an already deleted node is a no-op', () {
      DoubleProperty property;
      expect(
          () => property = deletedNode.doubleProperty('404'), returnsNormally);
      expect(() => property.setValue(404), returnsNormally);
      expect(() => readDouble(vmo, property), throwsA(anything),
          reason: 'cannot read VMO values from a deleted node');
    });

    test('Creating a StringProperty on an already deleted node is a no-op', () {
      StringProperty property;
      expect(
          () => property = deletedNode.stringProperty('404'), returnsNormally);
      expect(() => property.setValue('404'), returnsNormally);
      expect(() => readProperty(vmo, property.index), throwsA(anything),
          reason: 'cannot read VMO values from a deleted property');
    });

    test('Creating a ByteDataProperty on an already deleted node is a no-op',
        () {
      ByteDataProperty property;
      expect(() => property = deletedNode.byteDataProperty('404'),
          returnsNormally);
      expect(() => property.setValue(toByteData('fuchsia')), returnsNormally);
      expect(() => readProperty(vmo, property.index), throwsA(anything),
          reason: 'cannot read VMO values from a deleted property');
    });
  });

  group('Effects of deletion include: ', () {
    Node normalNode;

    setUp(() {
      normalNode = root.child('sheep');
    });

    test('child Node of deleted Node is deleted', () {
      var grandchild = normalNode.child('goats');
      normalNode.delete();
      expect(() => readNameIndex(vmo, grandchild), throwsA(anything),
          reason: 'child Node of deleted Node should be deleted');
    });

    test('child IntProperty of deleted Node is deleted', () {
      var intProperty = normalNode.intProperty('llamas');
      normalNode.delete();
      expect(() => readInt(vmo, intProperty), throwsA(anything),
          reason: 'child IntProperty of deleted Node should be deleted');
    });

    test('child DoubleProperty of deleted Node is deleted', () {
      var doubleProperty = normalNode.doubleProperty('emus');
      normalNode.delete();
      expect(() => readDouble(vmo, doubleProperty), throwsA(anything),
          reason: 'child DoubleProperty of deleted Node should be deleted');
    });

    test('child StringProperty of deleted Node is deleted', () {
      var stringProperty = normalNode.stringProperty('okapis');
      normalNode.delete();
      expect(() => readProperty(vmo, stringProperty.index), throwsA(anything),
          reason: 'child StringProperty of deleted Node should be deleted');
    });

    test('child ByteDataProperty of deleted Node is deleted', () {
      var byteDataProperty = normalNode.byteDataProperty('capybaras');
      normalNode.delete();
      expect(() => readProperty(vmo, byteDataProperty.index), throwsA(anything),
          reason: 'child ByteDataProperty of deleted Node should be deleted');
    });
  });

  group('VMO too small', () {
    Node tinyRoot;
    setUp(() {
      var tinyVmo = FakeVmo(64);
      var writer = VmoWriter(tinyVmo);
      var context = StartupContext.fromStartupInfo();
      Inspect inspect = InspectImpl(context, writer);
      tinyRoot = inspect.root;
    });

    test('If no space, creation gives a deleted Node', () {
      var missingNode = tinyRoot.child('missing');
      expect(() => missingNode.child('more missing'), returnsNormally);
      expect(() => readNameIndex(vmo, missingNode), throwsA(anything),
          reason: 'cannot read VMO values from a deleted node');
    });

    test('If no space, creation gives a deleted IntProperty', () {
      var missingProperty = tinyRoot.intProperty('missing');
      expect(() => missingProperty.setValue(1), returnsNormally);
      expect(() => readInt(vmo, missingProperty), throwsA(anything),
          reason: 'cannot read VMO values from a deleted metric');
    });

    test('If no space, creation gives a deleted DoubleProperty', () {
      var missingProperty = tinyRoot.doubleProperty('missing');
      expect(() => missingProperty.setValue(1.0), returnsNormally);
      expect(() => readDouble(vmo, missingProperty), throwsA(anything),
          reason: 'cannot read VMO values from a deleted metric');
    });

    test('If no space, creation gives a deleted StringProperty', () {
      var missingProperty = tinyRoot.stringProperty('missing');
      expect(() => missingProperty.setValue('something'), returnsNormally);
      expect(() => readProperty(vmo, missingProperty.index), throwsA(anything),
          reason: 'cannot read VMO values from a deleted property');
    });

    test('If no space, creation gives a deleted ByteDataProperty', () {
      var bytes = toByteData('this will not set');
      var missingProperty = tinyRoot.byteDataProperty('missing');
      expect(() => missingProperty.setValue(bytes), returnsNormally);
      expect(() => readProperty(vmo, missingProperty.index), throwsA(anything),
          reason: 'cannot read VMO values from a deleted property');
    });
  });
}
