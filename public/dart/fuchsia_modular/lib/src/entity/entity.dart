// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl_modular;
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

import '../internal/_component_context.dart';
import 'entity_codec.dart';
import 'entity_exceptions.dart';
import 'internal/_entity_impl.dart';
import 'internal/_link_entity.dart';

/// An [Entity] provides a mechanism for communicating
/// data between components.
///
/// Note: this is a preliminary API that is likely to change.
@experimental
abstract class Entity<T> {
  /// Creates an entity that will live for the scope of this story.
  /// The entity that is created will be backed by the framework and
  /// can be treated as if it was received from any other entity provider.
  ///
  /// Note: EntityCodec will be removed after soft transition
  factory Entity({
    EntityCodec<T> codec,
    String type,
    String entityReference,
  }) {
    if (codec != null) {
      // This is temporary and go away when we remove link entities.
      final linkName = Uuid().v4().toString();
      return LinkEntity<T>(linkName: linkName, codec: codec);
    } else if (T is Uint8List) {
      return Entity._resolved(entityReference: entityReference, type: type);
    }
    return null;
  }

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
  // note: hidden and static until soft transition completes at which point
  // will become `factory Entity(...)`
  // ignore: unused_element
  static Entity _resolved({
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
  Future<T> getData();

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
  Stream<T> watch();

  /// Writes the object stored in value
  Future<void> write(T object);
}
