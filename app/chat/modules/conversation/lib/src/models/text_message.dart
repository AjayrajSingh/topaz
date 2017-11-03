// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import 'message.dart';

/// A [Message] model representing a text message.
class TextMessage extends Message {
  /// The [text] message.
  final String text;

  /// Creates a new instance of [TextMessage].
  TextMessage({
    @required List<int> messageId,
    @required DateTime time,
    @required String sender,
    VoidCallback onDelete,
    @required this.text,
  })
      : assert(text != null),
        super(
          messageId: messageId,
          time: time,
          sender: sender,
          onDelete: onDelete,
        );

  @override
  String get type => 'text';

  @override
  Widget buildWidget() => new Text(text);
}
