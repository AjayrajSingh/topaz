// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import 'message.dart';

/// Enum for supported command types.
enum CommandType {
  /// Command to embed a mod.
  mod,
}

/// A [Message] model representing a slash command.
class CommandMessage extends Message {
  CommandType _command;
  List<String> _arguments;

  /// Creates a new instance of [CommandMessage].
  CommandMessage({
    @required List<int> messageId,
    @required DateTime time,
    @required String sender,
    VoidCallback onDelete,
    @required String payload,
  })
      : assert(payload != null),
        assert(payload.isNotEmpty),
        assert(CommandMessage.isCommand(payload)),
        super(
          messageId: messageId,
          time: time,
          sender: sender,
          onDelete: onDelete,
        ) {
    List<String> chunks = payload.split(' ');
    String first = chunks.removeAt(0);

    switch (first) {
      case '/mod':
        _command = CommandType.mod;
        break;
      default:
        throw new Exception('The "$first" command is not supported.');
    }

    _arguments = chunks;
  }

  /// Check if a string is a slash command.
  static bool isCommand(String string) {
    return (string == null || string.isEmpty) ? false : string[0] == '/';
  }

  @override
  String get type => 'command';

  @override
  bool get fillBubble => true;

  /// The [CommandType] for this [CommandMessage].
  CommandType get command => _command;

  /// The argument list for this [CommandMessage].
  List<String> get arguments => new UnmodifiableListView<String>(_arguments);

  @override
  Widget buildWidget() => new Text('$command');
}
