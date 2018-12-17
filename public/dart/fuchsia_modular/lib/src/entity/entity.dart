// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:fidl_fuchsia_mem/fidl_async.dart' as fuchsia_mem;
import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl_modular;
import 'package:meta/meta.dart';
import 'package:zircon/zircon.dart';

import '../internal/_component_context.dart';
import '../module/internal/_module_context.dart';
import 'entity_exceptions.dart';
import 'internal/_entity_impl.dart';

/// An [Entity] provides a mechanism for communicating
/// data between components.
///
/// Note: this is a preliminary API that is likely to change.
@experimental
abstract class Entity {
  /// Creates an Entity instance.
  ///
  /// This method will lazily connect to the entity proxy for data transmission.
  /// This object should be treated like it has a valid connection until
  /// otherwise informed via a failed future.
  ///
  /// ```
  ///   final entity = Entity(entityReference: 'foo', type: 'com.foo.bar');
  ///   // fetch the data assuming that the entity resolved correctly. If it
  ///   // did not the call to getData() will fail.
  ///   final data = await entity.getData();
  /// ```
  factory Entity({
    @required String entityReference,
    @required String type,
  }) {
    ArgumentError.checkNotNull(entityReference, 'entityReference');
    ArgumentError.checkNotNull(type, 'type');

    return EntityImpl(
      proxyFactory: () async {
        final resolver = fidl_modular.EntityResolverProxy();
        await getComponentContext().getEntityResolver(resolver.ctrl.request());

        final proxy = fidl_modular.EntityProxy();
        await resolver.resolveEntity(entityReference, proxy.ctrl.request());

        final types = await proxy.getTypes();
        if (!types.contains(type)) {
          throw EntityTypeException(type);
        }

        return proxy;
      },
      type: type,
    );
  }

  /// The type of data that this object represents.
  String get type;

  /// Returns the data stored in the entity.
  Future<Uint8List> getData();

  /// Returns the reference for this entity. Entity references will never change
  /// for a given entity so this value can be cached and used to access the
  /// entity from a different process or at a later time.
  Future<String> getEntityReference();

  /// Watches the entity for updates.
  ///
  /// An new value will be added to the stream whenever
  /// the entity is updated.
  ///
  /// The returned stream is a single subscription stream
  /// which, when closed, will close the underlying fidl
  /// connection.
  Stream<Uint8List> watch();

  /// Writes the object stored in value
  Future<void> write(Uint8List object);

  /// Creates an entity that will live for the scope of this story.
  /// The entity that is created will be backed by the framework and
  /// can be treated as if it was received from any other entity provider.
  static Future<Entity> createStoryScoped({
    @required String type,
    @required Uint8List initialData,
  }) async {
    ArgumentError.checkNotNull(type, 'type');
    ArgumentError.checkNotNull(initialData, 'initialData');

    if (type.isEmpty) {
      throw ArgumentError.value(type, 'type cannot be an empty string');
    }

    final context = getModuleContext();

    // need to create the proxy and write data immediately so other modules
    // can extract values
    final proxy = fidl_modular.EntityProxy();
    final vmo = SizedVmo.fromUint8List(initialData);
    final buffer = fuchsia_mem.Buffer(vmo: vmo, size: initialData.length);
    final ref = await context.createEntity(type, buffer, proxy.ctrl.request());

    // use the ref value to determine if creation was successful
    if (ref == null || ref.isEmpty) {
      throw Exception('Entity.createStoryScopedentity creation failed because'
          ' the framework was unable to create the entity.');
    }

    return EntityImpl(type: type, proxyFactory: () => proxy);
  }
}
