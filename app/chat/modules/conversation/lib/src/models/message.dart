// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// An abstract chat [Message] model. Each [Message] contains the timestamp and
/// the sender's email.
abstract class Message {
  /// The message id associated with this message.
  final List<int> messageId;

  /// The local time at which this chat message was added.
  final DateTime time;

  /// The email address of the sender.
  final String sender;

  /// Called when the user indicates that this message should be deleted.
  final VoidCallback onDelete;

  /// Creates a new instance of [Message].
  Message({
    @required this.messageId,
    @required this.time,
    @required this.sender,
    this.onDelete,
  }) {
    assert(time != null);
    assert(sender != null);
  }

  /// The type of the message. (e.g. 'text')
  String get type;

  /// Indicates whether the message should fill the chat bubble area or not.
  bool get fillBubble => false;

  /// Returns the [Widget] representation of this model.
  Widget buildWidget();
}
