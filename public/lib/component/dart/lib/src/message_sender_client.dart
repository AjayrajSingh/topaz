// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_mem/fidl.dart' as fuchsia_mem;
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:meta/meta.dart';
import 'package:zircon/zircon.dart';

/// Possible out-of-band error codes while using a message sender.
enum MessageSenderError {
  /// Message sender is no longer available. This error happens if the message
  /// queue was deleted, or the supplied token was not valid in the first place.
  unavailable
}

/// This is the function type that [MessageSenderClient] accepts for reporting
/// out-of-band errors.
typedef MessageSenderErrorCallback = void Function(
    MessageSenderError reason, String errMsg);

/// Wrapper class for the fuchsia.modular.MessageSender FIDL interface. This
/// class provides a more convenient interface for sending messages.
class MessageSenderClient {
  MessageSenderProxy _messageSenderProxy;
  MessageSenderErrorCallback _onConnectionError;

  /// The supplied error callback is called when the token or message queue
  /// no longer exists, or if the token is invalid.
  MessageSenderClient({@required MessageSenderErrorCallback onConnectionError})
      : assert(onConnectionError != null) {
    _onConnectionError = onConnectionError;
  }

  /// Will encode the given [message] as utf8 before sending the bytes over.
  /// TODO(MI4-1106): In the future there will be error handling in case
  /// [sendString] fails.
  void sendString(String message) {
    sendUint8List(Uint8List.fromList(utf8.encode(message)));
  }

  /// Send the given [message].
  void sendUint8List(Uint8List message) {
    _messageSenderProxy.send(new fuchsia_mem.Buffer(
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
    _messageSenderProxy.ctrl.error.then((ProxyError err) {
      if (_onConnectionError != null) {
        _onConnectionError(MessageSenderError.unavailable,
            'MessageSender not available for the provided token.');
      }
    });
    return _messageSenderProxy.ctrl.request();
  }
}
