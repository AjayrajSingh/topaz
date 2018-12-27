// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_mem/fidl_async.dart' as fuchsia_mem;
import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl_modular;
import 'package:meta/meta.dart';
import 'package:zircon/zircon.dart';

import '../entity.dart';
import '../entity_exceptions.dart';

typedef EntityProxyFactory = FutureOr<fidl_modular.Entity> Function();

/// A concrete implementation of the [Entity] class.
class EntityImpl implements Entity<Uint8List> {
  final _proxyMemo = AsyncMemoizer<fidl_modular.Entity>();

  @override
  final String type;

  final _entityReferenceMemo = AsyncMemoizer<String>();

  /// A function which returns a bound proxy on demand. This method will only be
  /// called once.
  final EntityProxyFactory proxyFactory;

  /// Constructs an instance of [EntityImpl].
  EntityImpl({
    @required this.proxyFactory,
    @required this.type,
  })  : assert(proxyFactory != null),
        assert(type != null && type.isNotEmpty);

  @override
  Future<Uint8List> getData() =>
      _getProxy().then((p) => p.getData(type)).then(_unwrapBuffer);

  @override
  Future<String> getEntityReference() => _entityReferenceMemo
      .runOnce(() => _getProxy().then((p) => p.getReference()));

  @override
  Stream<Uint8List> watch() {
    final controller = StreamController<fuchsia_mem.Buffer>();
    final watcher = _EntityWatcher(controller.add);

    // if the user closed the stream we close the binding to the watcher
    controller.onCancel = watcher.binding.close;

    // if the connection closes then we close the stream
    watcher.binding.whenClosed.then((_) {
      if (!controller.isClosed) {
        controller.close();
      }
    });

    _getProxy().then((proxy) {
      proxy.watch(type, watcher.getInterfaceHandle());
    });

    return controller.stream.asyncMap(_unwrapBuffer);
  }

  @override
  Future<void> write(Uint8List value) async {
    ArgumentError.checkNotNull(value, 'value');

    final vmo = SizedVmo.fromUint8List(value);
    final buffer = fuchsia_mem.Buffer(vmo: vmo, size: value.length);

    final proxy = await _getProxy();
    final result = await proxy.writeData(type, buffer);
    if (result != fidl_modular.EntityWriteStatus.ok) {
      throw EntityWriteException(result);
    }
  }

  Future<fidl_modular.Entity> _getProxy() => _proxyMemo.runOnce(proxyFactory);

  Uint8List _unwrapBuffer(fuchsia_mem.Buffer buffer) {
    final dataVmo = SizedVmo(buffer.vmo.handle, buffer.size);
    final result = dataVmo.read(buffer.size);

    if (result.status != 0) {
      throw Exception(
          'VMO read faile with status [${result.status}] when trying to read entity data with type [$type]');
    }

    dataVmo.close();
    return result.bytesAsUint8List();
  }
}

class _EntityWatcher implements fidl_modular.EntityWatcher {
  final fidl_modular.EntityWatcherBinding binding =
      fidl_modular.EntityWatcherBinding();
  final void Function(fuchsia_mem.Buffer) onUpdatedFunc;

  _EntityWatcher(this.onUpdatedFunc) : assert(onUpdatedFunc != null);

  InterfaceHandle<fidl_modular.EntityWatcher> getInterfaceHandle() {
    return binding.wrap(this);
  }

  @override
  Future<void> onUpdated(fuchsia_mem.Buffer data) async => onUpdatedFunc(data);
}
