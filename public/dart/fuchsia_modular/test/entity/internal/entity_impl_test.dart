// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:typed_data';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_mem/fidl_async.dart' as fuchsia_mem;
import 'package:fidl_fuchsia_modular/fidl_async.dart' as fuchsia_modular;
import 'package:fidl_fuchsia_modular/fidl_test.dart' as fuchsia_modular_test;
import 'package:fuchsia_modular/src/entity/entity_exceptions.dart';
import 'package:fuchsia_modular/src/entity/internal/_entity_impl.dart';
import 'package:test/test.dart';
import 'package:zircon/zircon.dart';

void main() {
  MockProxy proxy;
  EntityImpl entity;

  group('enity interactions', () {
    setUp(() {
      proxy = MockProxy();
      entity = EntityImpl(proxyFactory: () => proxy, type: 'foo');
    });

    tearDown(() {
      proxy = null;
      entity = null;
    });
    test('getData returns correct data', () async {
      final data = Uint8List.fromList([1, 2, 3]);
      await entity.write(data);
      expect(await entity.getData(), data);
    });

    test('write returns success for valid write', () async {
      final data = Uint8List.fromList([1, 2, 3]);
      await entity.write(data);
      // test will fail if write fails
    });

    test('write fails for error in write', () async {
      proxy.writeStatus = fuchsia_modular.EntityWriteStatus.error;
      final data = Uint8List.fromList([1, 2, 3]);
      expect(entity.write(data),
          throwsA(const TypeMatcher<EntityWriteException>()));
    });

    test('write fails for readonly', () async {
      proxy.writeStatus = fuchsia_modular.EntityWriteStatus.readOnly;
      final data = Uint8List.fromList([1, 2, 3]);
      expect(entity.write(data),
          throwsA(const TypeMatcher<EntityWriteException>()));
    });

    test('getEntityReference returns the correct ref', () async {
      proxy.entityReference = 'my-entity';
      expect(await entity.getEntityReference(), 'my-entity');
    });

    test('watch closes stream when binding is closed', () {
      proxy.forceCloseWatchers = true;
      final stream = entity.watch();
      expect(stream, emitsInOrder([emitsDone]));
    });

    test('watch udpates stream', () async {
      Uint8List _bufferWithValue(int v) {
        final data = ByteData(1)..setInt8(0, v);
        return data.buffer.asUint8List();
      }

      int _getValue(Uint8List buffer) {
        return ByteData.view(buffer.buffer).getInt8(0);
      }

      final stream = entity.watch();

      expect(stream.map(_getValue), emitsInOrder([1, 2, 3]));

      await entity.write(_bufferWithValue(1));
      await entity.write(_bufferWithValue(2));
      await entity.write(_bufferWithValue(3));
    });
  });
}

class MockProxy extends fuchsia_modular_test.Entity$TestBase {
  Uint8List _data;
  String entityReference;
  List<fuchsia_modular.EntityWatcherProxy> watchers = [];

  /// if set to true the watchers will be closed after they are added.
  bool forceCloseWatchers = false;

  /// Can be set to control how write results are handled.
  fuchsia_modular.EntityWriteStatus writeStatus =
      fuchsia_modular.EntityWriteStatus.ok;

  @override
  Future<fuchsia_mem.Buffer> getData(String _) async {
    final vmo = SizedVmo.fromUint8List(_data);
    final buffer = fuchsia_mem.Buffer(vmo: vmo, size: _data.length);
    return buffer;
  }

  @override
  Future<String> getReference() async => entityReference;

  @override
  Future<void> watch(String type,
      InterfaceHandle<fuchsia_modular.EntityWatcher> watcher) async {
    final proxy = fuchsia_modular.EntityWatcherProxy();
    proxy.ctrl.bind(watcher);
    watchers.add(proxy);

    if (forceCloseWatchers) {
      //ignore: unawaited_futures
      Future(proxy.ctrl.close);
    }
  }

  @override
  Future<fuchsia_modular.EntityWriteStatus> writeData(
      String type, fuchsia_mem.Buffer buffer) async {
    if (writeStatus != fuchsia_modular.EntityWriteStatus.ok) {
      return writeStatus;
    }

    final dataVmo = SizedVmo(buffer.vmo.handle, buffer.size);
    final result = dataVmo.read(buffer.size);
    dataVmo.close();
    final data = result.bytesAsUint8List();
    _setData(data, notify: true);
    return fuchsia_modular.EntityWriteStatus.ok;
  }

  void _setData(Uint8List data, {bool notify = false}) {
    _data = data;
    if (notify) {
      final vmo = SizedVmo.fromUint8List(data);
      final buffer = fuchsia_mem.Buffer(vmo: vmo, size: data.length);
      for (final watcher in watchers) {
        if (watcher.ctrl.isBound) {
          watcher.onUpdated(buffer);
        }
      }
    }
  }
}
