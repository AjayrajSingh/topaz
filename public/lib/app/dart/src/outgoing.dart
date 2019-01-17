// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file

import 'package:fuchsia_vfs/vfs.dart' as vfs;
import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_io/fidl_async.dart';

/// Helper class to publish outgoing services and other directories for debug
/// and control purposes
class Outgoing {
  final vfs.PseudoDir _root = vfs.PseudoDir();
  final vfs.PseudoDir _public = vfs.PseudoDir();
  final vfs.PseudoDir _debug = vfs.PseudoDir();
  final vfs.PseudoDir _ctrl = vfs.PseudoDir();
  bool _isClosed = false;

  /// This will setup outgoing directory and add required
  /// directories to root of this class.
  ///
  /// This class will throw an Exception if its methods are called
  /// after it is closed. Calling close twice doesn't cause exception.
  Outgoing() {
    _root
      ..addNode('public', _public)
      ..addNode('debug', _debug)
      ..addNode('ctrl', _ctrl);
  }

  void _ensureNotClosed() {
    if (_isClosed) {
      throw Exception('Outgoing closed');
    }
  }

  /// deprecated method, until we change all reference to use [addPublicService].
  void addServiceForName<T>(vfs.Connector<T> connector, String serviceName) {
    addPublicService(connector, serviceName);
  }

  /// Serves root dir to request channel and serve [fuchsia.io.Directory]
  ///  over it.
  void serve(InterfaceRequest<Node> request) {
    _ensureNotClosed();
    _root.serve(request);
  }

  /// Closes root directory
  void close() {
    if (_isClosed) {
      return;
    }
    _root.close();
    _isClosed = true;
  }

  /// return root directory which can be used to host other directories
  /// and extend this class.
  vfs.PseudoDir rootDir() {
    _ensureNotClosed();
    return _root;
  }

  /// return debug directory which can be used to publish debug info to /hub
  vfs.PseudoDir debugDir() {
    _ensureNotClosed();
    return _debug;
  }

  /// return public directory which usually contains all published services.
  vfs.PseudoDir publicDir() {
    _ensureNotClosed();
    return _public;
  }

  /// return ctrl directory which can be used to publish control information
  /// for /hub and system.
  vfs.PseudoDir ctrlDir() {
    _ensureNotClosed();
    return _ctrl;
  }

  /// Add and publish a public service.
  /// Will return ZX_OK if successful, else will return error status.
  int addPublicService<T>(vfs.Connector<T> connector, String serviceName) {
    _ensureNotClosed();
    var service = vfs.Service.withConnector(connector);
    int status = _public.addNode(serviceName, service);
    return status;
  }
}
