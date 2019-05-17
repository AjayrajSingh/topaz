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
  Node node;

  setUp(() {
    var context = StartupContext.fromStartupInfo();
    vmo = FakeVmo(512);
    var writer = VmoWriter(vmo);
    Inspect inspect = InspectImpl(context, writer);
    node = inspect.root;
  });

  group('String properties', () {
    test('are written to the VMO when the value is set', () {
      var property = node.stringProperty('color')..setValue('fuchsia');

      expect(readProperty(vmo, property.index),
          equalsByteData(toByteData('fuchsia')));
    });

    test('can be mutated', () {
      var property = node.stringProperty('breakfast')..setValue('pancakes');

      expect(readProperty(vmo, property.index),
          equalsByteData(toByteData('pancakes')));

      property.setValue('waffles');
      expect(readProperty(vmo, property.index),
          equalsByteData(toByteData('waffles')));
    });

    test('can be deleted', () {
      var property = node.stringProperty('scallops');
      var index = property.index;

      property.delete();

      expect(() => readProperty(vmo, index),
          throwsA(const TypeMatcher<StateError>()),
          reason: 'cannot read VMO values from a deleted property');
    });

    test('setting a value on an already deleted property is a no-op', () {
      var property = node.stringProperty('paella');
      var index = property.index;
      property.delete();

      expect(() => property.setValue('this will not set'), returnsNormally);
      expect(() => readProperty(vmo, index),
          throwsA(const TypeMatcher<StateError>()),
          reason: 'cannot read VMO values from a deleted property');
    });

    test('removing an already deleted property is a no-op', () {
      var property = node.stringProperty('nothing-here')..delete();

      expect(() => property.delete(), returnsNormally);
    });
  });

  group('ByteData properties', () {
    test('are written to the VMO when the property is set', () {
      var bytes = toByteData('fuchsia');
      var property = node.byteDataProperty('color')..setValue(bytes);

      expect(readProperty(vmo, property.index), equalsByteData(bytes));
    });

    test('can be mutated', () {
      var pancakes = toByteData('pancakes');
      var property = node.byteDataProperty('breakfast')..setValue(pancakes);

      expect(readProperty(vmo, property.index), equalsByteData(pancakes));

      var waffles = toByteData('waffles');
      property.setValue(waffles);
      expect(readProperty(vmo, property.index), equalsByteData(waffles));
    });

    test('can be deleted', () {
      var property = node.byteDataProperty('scallops');
      var index = property.index;

      property.delete();

      expect(() => readProperty(vmo, index),
          throwsA(const TypeMatcher<StateError>()),
          reason: 'cannot read VMO values from a deleted property');
    });

    test('setting a value on an already deleted property is a no-op', () {
      var property = node.byteDataProperty('paella');
      var index = property.index;
      property.delete();

      var bytes = toByteData('this will not set');
      expect(() => property.setValue(bytes), returnsNormally);
      expect(() => readProperty(vmo, index),
          throwsA(const TypeMatcher<StateError>()),
          reason: 'cannot read VMO values from a deleted property');
    });

    test('removing an already deleted property is a no-op', () {
      var property = node.byteDataProperty('nothing-here')..delete();

      expect(() => property.delete(), returnsNormally);
    });
  });

  group('Property creation (byte-vector properties)', () {
    test('StringProperties created twice return the same object', () {
      var childProperty = node.stringProperty('banana');
      var childProperty2 = node.stringProperty('banana');

      expect(childProperty, isNotNull);
      expect(childProperty2, isNotNull);
      expect(childProperty, same(childProperty2));
    });

    test('StringProperties created after deletion return different objects',
        () {
      var childProperty = node.stringProperty('banana')..delete();
      var childProperty2 = node.stringProperty('banana');

      expect(childProperty, isNotNull);
      expect(childProperty2, isNotNull);
      expect(childProperty, isNot(equals(childProperty2)));
    });

    test('ByteDataProperties created twice return the same object', () {
      var childProperty = node.byteDataProperty('banana');
      var childProperty2 = node.byteDataProperty('banana');

      expect(childProperty, isNotNull);
      expect(childProperty2, isNotNull);
      expect(childProperty, same(childProperty2));
    });

    test('ByteDataProperties created after deletion return different objects',
        () {
      var childProperty = node.byteDataProperty('banana')..delete();
      var childProperty2 = node.byteDataProperty('banana');

      expect(childProperty, isNotNull);
      expect(childProperty2, isNotNull);
      expect(childProperty, isNot(equals(childProperty2)));
    });

    test('Changing StringProperty to ByteDataProperty throws', () {
      node.stringProperty('banana');
      expect(() => node.byteDataProperty('banana'),
          throwsA(const TypeMatcher<InspectStateError>()));
    });

    test('Changing StringProperty to IntProperty throws', () {
      node.stringProperty('banana');
      expect(() => node.intProperty('banana'),
          throwsA(const TypeMatcher<InspectStateError>()));
    });

    test('Changing StringProperty to DoubleProperty throws', () {
      node.stringProperty('banana');
      expect(() => node.doubleProperty('banana'),
          throwsA(const TypeMatcher<InspectStateError>()));
    });

    test('Changing ByteDataProperty to StringProperty throws', () {
      node.byteDataProperty('banana');
      expect(() => node.stringProperty('banana'),
          throwsA(const TypeMatcher<InspectStateError>()));
    });

    test('Changing ByteDataProperty to IntProperty throws', () {
      node.byteDataProperty('banana');
      expect(() => node.intProperty('banana'),
          throwsA(const TypeMatcher<InspectStateError>()));
    });

    test('Changing ByteDataProperty to DoubleProperty throws', () {
      node.byteDataProperty('banana');
      expect(() => node.doubleProperty('banana'),
          throwsA(const TypeMatcher<InspectStateError>()));
    });

    test('If no space, creation gives a deleted StringProperty', () {
      var tinyVmo = FakeVmo(64);
      var writer = VmoWriter(tinyVmo);
      var context = StartupContext.fromStartupInfo();
      Inspect inspect = InspectImpl(context, writer);
      var tinyRoot = inspect.root;
      var missingProperty = tinyRoot.stringProperty('missing');
      expect(() => missingProperty.setValue('something'), returnsNormally);
      expect(() => readProperty(vmo, missingProperty.index),
          throwsA(const TypeMatcher<StateError>()),
          reason: 'cannot read VMO values from a deleted property');
    });

    test('If no space, creation gives a deleted ByteDataProperty', () {
      var tinyVmo = FakeVmo(64);
      var writer = VmoWriter(tinyVmo);
      var context = StartupContext.fromStartupInfo();
      Inspect inspect = InspectImpl(context, writer);
      var tinyRoot = inspect.root;
      var bytes = toByteData('this will not set');
      var missingProperty = tinyRoot.byteDataProperty('missing');
      expect(() => missingProperty.setValue(bytes), returnsNormally);
      expect(() => readProperty(vmo, missingProperty.index),
          throwsA(const TypeMatcher<StateError>()),
          reason: 'cannot read VMO values from a deleted property');
    });
  });

  group('Int Properties', () {
    test('are created with value 0', () {
      var property = node.intProperty('foo');

      expect(readInt(vmo, property), isZero);
    });

    test('are written to the VMO when the value is set', () {
      var property = node.intProperty('eggs')..setValue(12);

      expect(readInt(vmo, property), 12);
    });

    test('can be mutated', () {
      var property = node.intProperty('locusts')..setValue(10);
      expect(readInt(vmo, property), 10);

      property.setValue(1000);

      expect(readInt(vmo, property), 1000);
    });

    test('can add arbitrary values', () {
      var property = node.intProperty('bagels')..setValue(13);
      expect(readInt(vmo, property), 13);

      property.add(13);

      expect(readInt(vmo, property), 26);
    });

    test('can subtract arbitrary values', () {
      var property = node.intProperty('bagels')..setValue(13);
      expect(readInt(vmo, property), 13);

      property.subtract(6);

      expect(readInt(vmo, property), 7);
    });

    test('can be deleted', () {
      var property = node.intProperty('sheep')..delete();

      expect(() => readInt(vmo, property),
          throwsA(const TypeMatcher<StateError>()),
          reason: 'cannot read VMO values from a deleted property');
    });

    test('setting a value on an already deleted property is a no-op', () {
      var property = node.intProperty('webpages')..delete();

      expect(() => property.setValue(404), returnsNormally);
      expect(() => readInt(vmo, property),
          throwsA(const TypeMatcher<StateError>()),
          reason: 'cannot read VMO values from a deleted property');
    });

    test('removing an already deleted property is a no-op', () {
      var property = node.intProperty('nothing-here')..delete();

      expect(() => property.delete(), returnsNormally);
    });
  });

  group('DoubleProperties', () {
    test('are created with value 0', () {
      var property = node.doubleProperty('foo');

      expect(readDouble(vmo, property), isZero);
    });

    test('are written to the VMO when the value is set', () {
      var property = node.doubleProperty('foo')..setValue(2.5);

      expect(readDouble(vmo, property), 2.5);
    });

    test('can be mutated', () {
      var property = node.doubleProperty('bar')..setValue(3.0);
      expect(readDouble(vmo, property), 3.0);

      property.setValue(3.5);

      expect(readDouble(vmo, property), 3.5);
    });

    test('can add arbitrary values', () {
      var property = node.doubleProperty('cake')..setValue(1.5);
      expect(readDouble(vmo, property), 1.5);

      property.add(1.5);

      expect(readDouble(vmo, property), 3);
    });

    test('can subtract arbitrary values', () {
      var property = node.doubleProperty('cake')..setValue(5);
      expect(readDouble(vmo, property), 5);

      property.subtract(0.5);

      expect(readDouble(vmo, property), 4.5);
    });

    test('can be deleted', () {
      var property = node.doubleProperty('circumference')..delete();

      expect(() => readDouble(vmo, property),
          throwsA(const TypeMatcher<StateError>()),
          reason: 'cannot read VMO values from a deleted property');
    });

    test('setting a value on an already deleted property is a no-op', () {
      var property = node.doubleProperty('pounds')..delete();

      expect(() => property.setValue(50.6), returnsNormally);
      expect(() => readDouble(vmo, property),
          throwsA(const TypeMatcher<StateError>()),
          reason: 'cannot read VMO values from a deleted property');
    });

    test('removing an already deleted property is a no-op', () {
      var property = node.doubleProperty('nothing-here')..delete();

      expect(() => property.delete(), returnsNormally);
    });
  });

  group('property creation', () {
    test('IntProperties created twice return the same object', () {
      var childProperty = node.intProperty('banana');
      var childProperty2 = node.intProperty('banana');

      expect(childProperty, isNotNull);
      expect(childProperty2, isNotNull);
      expect(childProperty, same(childProperty2));
    });

    test('IntProperties created after deletion return different objects', () {
      var childProperty = node.intProperty('banana')..delete();
      var childProperty2 = node.intProperty('banana');

      expect(childProperty, isNotNull);
      expect(childProperty2, isNotNull);
      expect(childProperty, isNot(equals(childProperty2)));
    });

    test('DoubleProperties created twice return the same object', () {
      var childProperty = node.doubleProperty('banana');
      var childProperty2 = node.doubleProperty('banana');

      expect(childProperty, isNotNull);
      expect(childProperty2, isNotNull);
      expect(childProperty, same(childProperty2));
    });

    test('DoubleProperties created after deletion return different objects',
        () {
      var childProperty = node.doubleProperty('banana')..delete();
      var childProperty2 = node.doubleProperty('banana');

      expect(childProperty, isNotNull);
      expect(childProperty2, isNotNull);
      expect(childProperty, isNot(equals(childProperty2)));
    });

    test('Changing IntProperty to DoubleProperty throws', () {
      node.intProperty('banana');
      expect(() => node.doubleProperty('banana'),
          throwsA(const TypeMatcher<InspectStateError>()));
    });

    test('Changing IntProperty to StringProperty throws', () {
      node.intProperty('banana');
      expect(() => node.stringProperty('banana'),
          throwsA(const TypeMatcher<InspectStateError>()));
    });

    test('Changing IntProperty to ByteDataProperty throws', () {
      node.intProperty('banana');
      expect(() => node.byteDataProperty('banana'),
          throwsA(const TypeMatcher<InspectStateError>()));
    });

    test('Changing DoubleProperty to IntProperty throws', () {
      node.doubleProperty('banana');
      expect(() => node.intProperty('banana'),
          throwsA(const TypeMatcher<InspectStateError>()));
    });

    test('Changing DoubleProperty to StringProperty throws', () {
      node.doubleProperty('banana');
      expect(() => node.stringProperty('banana'),
          throwsA(const TypeMatcher<InspectStateError>()));
    });

    test('Changing DoubleProperty to ByteDataProperty throws', () {
      node.doubleProperty('banana');
      expect(() => node.byteDataProperty('banana'),
          throwsA(const TypeMatcher<InspectStateError>()));
    });

    test('If no space, creation gives a deleted IntProperty', () {
      var tinyVmo = FakeVmo(64);
      var writer = VmoWriter(tinyVmo);
      var context = StartupContext.fromStartupInfo();
      Inspect inspect = InspectImpl(context, writer);
      var tinyRoot = inspect.root;
      var missingProperty = tinyRoot.intProperty('missing');
      expect(() => missingProperty.setValue(1), returnsNormally);
      expect(() => readInt(vmo, missingProperty),
          throwsA(const TypeMatcher<StateError>()),
          reason: 'cannot read VMO values from a deleted property');
    });

    test('If no space, creation gives a deleted DoubleProperty', () {
      var tinyVmo = FakeVmo(64);
      var writer = VmoWriter(tinyVmo);
      var context = StartupContext.fromStartupInfo();
      Inspect inspect = InspectImpl(context, writer);
      var tinyRoot = inspect.root;
      var missingProperty = tinyRoot.doubleProperty('missing');
      expect(() => missingProperty.setValue(1.0), returnsNormally);
      expect(() => readDouble(vmo, missingProperty),
          throwsA(const TypeMatcher<StateError>()),
          reason: 'cannot read VMO values from a deleted property');
    });
  });
}
