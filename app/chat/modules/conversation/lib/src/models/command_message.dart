// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';
import 'package:meta/meta.dart';

import 'message.dart';

/// Function signature for an additional command initialization.
typedef void CommandInitializer(List<String> args);

/// Enum for supported command types.
enum CommandType {
  /// Command to embed a mod.
  mod,
}

/// A [Message] model representing a slash command.
class CommandMessage extends Message {
  /// The embedder associated with this command message.
  final EmbedderModel embedder;

  /// String paylod of the message contents.
  final String payload;

  /// String list of members in the chat convo.
  final List<String> members;

  CommandType _command;
  List<String> _arguments;

  /// Creates a new instance of [CommandMessage].
  CommandMessage({
    @required this.members,
    @required this.embedder,
    @required List<int> messageId,
    @required DateTime time,
    @required String sender,
    VoidCallback onDelete,
    @required this.payload,
    CommandInitializer initializer,
  })
      : assert(embedder != null),
        assert(payload != null),
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
    }

    _arguments = chunks;

    // Perform additional initialization if necessary.
    initializer?.call(_arguments);
  }

  /// Check if a string is a slash command.
  static bool isCommand(String string) {
    return (string == null || string.isEmpty) ? false : string[0] == '/';
  }

  @override
  String get type => 'command';

  @override
  bool get fillBubble => _command == null ? false : true;

  /// The [CommandType] for this [CommandMessage].
  CommandType get command => _command;

  /// The argument list for this [CommandMessage].
  List<String> get arguments => new UnmodifiableListView<String>(_arguments);

  @override
  Widget buildWidget() {
    /// Connect the [EmbedderModel] parent to the nodes built in
    /// [buildEmbeddedModule].
    return new AnimatedBuilder(
      animation: embedder,
      builder: buildEmbeddedModule,
    );
  }

  /// Command specific rendering, delelgates to the embedder for the mod
  /// command.
  Widget buildEmbeddedModule(
    BuildContext context,
    Widget child,
  ) {
    Widget content;
    if (_command == null) {
      content = new Text(
        payload,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      );
    } else {
      content = embedder.build(context);
    }

    return content;
  }
}
