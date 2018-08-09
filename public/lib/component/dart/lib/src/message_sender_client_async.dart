// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_mem/fidl_async.dart' as fuchsia_mem;
import 'package:fidl_fuchsia_modular/fidl_async.dart';
import 'package:zircon/zircon.dart';

/// Wrapper class for the async fuchsia.modular.MessageSender FIDL interface.
/// This class provides a more convenient interface for sending messages.
/// TODO: Rename to MessageSenderClient once all relevant code switched to
/// the async fidl bindings.
class MessageSenderClientAsync {
  MessageSenderProxy _messageSenderProxy;

  /// The supplied error callback is called when the token or message queue
  /// no longer exists, or if the token is invalid.
  MessageSenderClientAsync();

  /// Will encode the given [message] as utf8 before sending the bytes over.
  /// TODO(MI4-1106): In the future there will be error handling in case
  /// [sendString] fails.
  Future<void> sendString(String message) {
    return sendUint8List(Uint8List.fromList(utf8.encode(message)));
  }

  /// Send the given [message].
  Future<void> sendUint8List(Uint8List message) {
    return _messageSenderProxy.send(new fuchsia_mem.Buffer(
      vmo: new SizedVmo.fromUint8List(message),
      size: message.length,
    ));
  }

  /// Close the underlying MessageSenderProxy.
  void close() {
    _messageSenderProxy?.ctrl?.close();
  }

  /// Binds a new MessageSenderProxy to this class and returns the request-side.
  /// Closes the previously bound proxy if one exists.
  InterfaceRequest<MessageSender> newRequest() {
    if (_messageSenderProxy != null && _messageSenderProxy.ctrl.isBound) {
      _messageSenderProxy.ctrl.close();
    }

    _messageSenderProxy = new MessageSenderProxy();
    return _messageSenderProxy.ctrl.request();
  }
}
