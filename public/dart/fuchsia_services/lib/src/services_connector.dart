// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_io/fidl_async.dart';
import 'package:zircon/zircon.dart';

/// Facilitate the ability to connect to services outside of the Modular
/// Framework, for example via a command-line tool.
///
/// The user is responsible to launch a component and wire up a connection
/// between the new launched component and the request returned from this
/// [ServicesConnection.request()]. This is typically done using
/// [StartupContext#launcher].
///
/// For Module Framework APIs see `package:fuchsia_modular`
class ServicesConnector {
  DirectoryProxy _dirProxy;

  /// Creates a interface request, binds one of the channels to this object, and
  /// returns the other channel.
  ///
  /// Note: previously returned [Channel] will no longer be associate with this
  /// object.
  Channel request() {
    _dirProxy = DirectoryProxy();
    return _dirProxy.ctrl.request().passChannel();
  }

  /// Connects the most recently returned [Channel] from [request()] with the
  /// provided services represented by its [controller].
  Future<void> connectToService<T>(ProxyController<T> controller) async {
    final String serviceName = controller.$serviceName;
    if (serviceName == null) {
      throw Exception(
          "${controller.$interfaceName}'s controller.\$serviceName must "
          'not be null. Check the FIDL file for a missing [Discoverable]');
    }
    await _open(serviceName,
        InterfaceRequest<Node>(controller.request().passChannel()));
  }

  /// Connects the most recently returned [Channel] from [request()] with the
  /// provided services represented by its [serviceName].
  Future<InterfaceHandle<T>> connectToServiceByName<T>(
      String serviceName) async {
    final ChannelPair pair = ChannelPair();
    await _open(serviceName, InterfaceRequest<Node>(pair.first));
    return InterfaceHandle<T>(pair.second);
  }

  /// Terminates connection and return Zircon status.
  Future<int> close() async {
    return _dirProxy.close();
  }

  // Open a new object relative to this directory object
  Future<void> _open(String serviceName, InterfaceRequest<Node> object) async {
    // connection flags for service: can read & write from target object.
    const int _openFlags = openRightReadable | openRightWritable;
    // 0755
    const int _openMode = 0x1ED;

    return _dirProxy.open(_openFlags, _openMode, serviceName, object);
  }
}
