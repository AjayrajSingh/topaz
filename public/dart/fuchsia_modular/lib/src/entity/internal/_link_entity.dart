// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_mem/fidl_async.dart' as fuchsia_mem;
import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl;
import 'package:fuchsia/services.dart';
import 'package:meta/meta.dart';
import 'package:zircon/zircon.dart';

import '../../module/internal/_module_context.dart';
import '../entity.dart';
import '../entity_codec.dart';

/// An [Entity] implementation which supports
/// data that lives inside links.
///
/// Note: This is a temporary solution that will go away when links are removed.
class LinkEntity<T> implements Entity<T> {
  /// The name of the link to pull data from
  final String linkName;

  /// The codec used to decode/encode data
  final EntityCodec codec;

  fidl.Link _link;

  /// Constructor
  LinkEntity({
    @required this.linkName,
    @required this.codec,
  });

  @override
  Future<T> getData() async => _getSnapshot();

  @override
  Stream<T> watch() {
    final link = _getLink();
    final controller = StreamController<fuchsia_mem.Buffer>();
    final watcher = _LinkWatcher(onNotify: (buffer) async {
      controller.add(buffer);
    });

    link.watch(watcher.getInterfaceHandle());

    // if the user closed the stream we close the binding to the watcher
    controller.onCancel = watcher.binding.close;

    // if the connection closes then we close the stream
    watcher.binding.whenClosed.then((_) {
      if (!controller.isClosed) {
        controller.close();
      }
    });

    // Use _getSnapshot here instead of using the buffer directly because
    // most uses of links are using the entityRef value on the link instead
    // of raw json.
    return controller.stream.asyncMap((_) => _getSnapshot());
  }

  @override
  Future<void> write(T value) {
    // TODO: implement write
    return null;
  }

  Future<T> _getEntityData<T>(String entityReference) async {
    final resolver = fidl.EntityResolverProxy();
    await getComponentContext().getEntityResolver(resolver.ctrl.request());

    final entity = fidl.EntityProxy();
    await resolver.resolveEntity(entityReference, entity.ctrl.request());

    final types = await entity.getTypes();
    if (!types.contains(codec.type)) {
      throw EntityTypeException(codec.type);
    }

    final buffer = await entity.getData(codec.type);
    final dataVmo = SizedVmo(buffer.vmo.handle, buffer.size);
    final result = dataVmo.read(buffer.size);

    if (result.status != 0) {
      throw new Exception('Failed to read VMO');
    }

    dataVmo.close();

    return codec.decode(result.bytesAsUint8List());
  }

  // Returns a [fidl.Link] proxy object which is connected via the
  // module context. Callers of this method are responsible for closing
  // the link connection when they are done.
  T _getJsonData<T>(fuchsia_mem.Buffer json) {
    final vmo = SizedVmo(json.vmo.handle, json.size);
    final result = vmo.read(json.size);
    if (result.status != 0) {
      throw Exception('Failed to read VMO');
    }
    vmo.close();

    return codec.decode(result.bytesAsUint8List());
  }

  fidl.Link _getLink() {
    if (_link != null) {
      return _link;
    }

    // Store the Link instead of the LinkProxy to avoid closing.
    fidl.LinkProxy linkProxy = fidl.LinkProxy();
    _link = linkProxy;
    getModuleContext().getLink(linkName, linkProxy.ctrl.request());

    return _link;
  }

  Future<T> _getSnapshot() async {
    final link = _getLink();

    final entityReference = await link.getEntity();
    if (entityReference == null) {
      final buffer = await link.get(null);
      if (buffer == null) {
        return null;
      }
      return _getJsonData(buffer);
    }

    return _getEntityData(entityReference);
  }
}

class _LinkWatcher extends fidl.LinkWatcher {
  final fidl.LinkWatcherBinding binding = fidl.LinkWatcherBinding();
  final Future<void> Function(fuchsia_mem.Buffer) onNotify;

  _LinkWatcher({@required this.onNotify}) : assert(onNotify != null);

  InterfaceHandle<fidl.LinkWatcher> getInterfaceHandle() {
    if (binding.isBound) {
      throw Exception(
          'Attempting to call _LinkWatcher.getInterfaceHandle on already bound binding');
    }
    return binding.wrap(this);
  }

  @override
  Future<void> notify(fuchsia_mem.Buffer data) => onNotify(data);
}
