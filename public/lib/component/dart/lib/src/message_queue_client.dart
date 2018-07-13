// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:fidl/fidl.dart';
import 'package:zircon/zircon.dart';
import 'package:fidl_fuchsia_mem/fidl.dart' as fuchsia_mem;
import 'package:meta/meta.dart';

/// [MessageQueueClient] will forward new messages to a function of this type,
/// along with an [ack] callback that the user must call on receipt of the
/// message.
typedef MessageReceiverCallback = void Function(
    Uint8List message, void Function() ack);

/// Possible error codes while listening for new messages.
enum MessageQueueError {
  /// Message queue is not available. This error isn't expected to happen during
  /// normal function; it is the catch-all IPC-level error.
  unavailable
}

/// [MessageQueueClient] errors are reported to this callback type.
typedef MessageQueueErrorCallback = void Function(
    MessageQueueError reason, String errMsg);

/// Helper class for receiving messages on a given message queue.
class MessageQueueClient extends MessageReader {
  MessageQueueProxy _queue;
  final MessageReaderBinding _readerBinding = new MessageReaderBinding();

  /// [onMessage] is called when there is a new message.
  final MessageReceiverCallback onMessage;

  /// [onConnectionError] is called with an error code when there is an
  /// out-of-band error.
  final MessageQueueErrorCallback onConnectionError;

  /// Constructor. An error callback must be supplied which is called when the
  /// MessageQueue is no longer available (it may have been deleted, or it may
  /// not have existed in the first place).  The supplied receiver callback is
  /// called there are new messages to process, and an acknowledgement callback
  /// is supplied to the receiver callback, who calls it to say that the message
  /// has been processed, so it won't be delivered again in case there are
  /// failures.
  MessageQueueClient({
    @required this.onMessage,
    @required this.onConnectionError,
  })  : assert(onConnectionError != null),
        assert(onMessage != null);

  /// Binds a new MessageQueue proxy and returns the request-side interface.
  InterfaceRequest<MessageQueue> newRequest() {
    _queue?.ctrl?.close();
    _queue ??= new MessageQueueProxy();
    _queue.ctrl.error.then((ProxyError err) {
      if (onConnectionError != null) {
        onConnectionError(MessageQueueError.unavailable,
            'MessageQueue is no longer available');
      }
    });
    var request = _queue.ctrl.request();
    _queue.registerReceiver(_readerBinding.wrap(this));
    return request;
  }

  /// Get a token for this message queue. Agents can use this token to register
  /// for triggers. Components can use this token to send message over this
  /// message queue.
  Future<String> getToken() {
    assert(_queue.ctrl.isBound);

    Completer<String> result;
    _queue.getToken((String token) {
      result.complete(token);
    });
    return result.future;
  }

  /// Closes the [MessageQueue] binding and stops receiving any new messages by
  /// closing the underlying [MessageReader] interface.
  void close() {
    _queue?.ctrl?.close();
    _queue = null;
    _readerBinding.close();
  }

  /// Not public; implements [MessageReader.onReceive].
  @override
  void onReceive(fuchsia_mem.Buffer message, void Function() ack) {
    var dataVmo = new SizedVmo(message.vmo.handle, message.size);
    var data = dataVmo.map();
    dataVmo.close();
    onMessage.call(data, ack);
  }
}
