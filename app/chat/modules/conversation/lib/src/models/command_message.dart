// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';
import 'package:meta/meta.dart';

import 'message.dart';

/// Function signature for an additional command initialization.
typedef CommandInitializer = void Function(
    CommandType commandType, List<String> args);

/// Enum for supported command types.
enum CommandType {
  /// Command to embed a mod.
  mod,

  /// Command to embed a video.
  video,
}

/// A [Message] model representing a slash command.
class CommandMessage extends Message {
  /// The embedder associated with this command message.
  final EmbedderModel embedder;

  /// String paylod of the message contents.
  final String payload;

  /// String list of members in the chat convo.
  final List<String> members;

  /// Called when the refresh button is tapped.
  final VoidCallback onRefresh;

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
    this.onRefresh,
    @required this.payload,
    CommandInitializer initializer,
  })  : assert(embedder != null),
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

      case '/video':
        _command = CommandType.video;
        break;
    }

    _arguments = chunks;

    // Perform additional initialization if necessary.
    initializer?.call(command, arguments);
  }

  /// Check if a string is a slash command.
  static bool isCommand(String string) {
    return (string == null || string.isEmpty) ? false : string[0] == '/';
  }

  @override
  String get type => 'command';

  @override
  bool get fillBubble => _command == null ? false : true;

  @override
  bool get longPressDeleteEnabled => false;

  /// The [CommandType] for this [CommandMessage].
  CommandType get command => _command;

  /// The argument list for this [CommandMessage].
  List<String> get arguments => new UnmodifiableListView<String>(_arguments);

  @override
  Widget buildWidget() {
    List<Widget> children = <Widget>[
      /// Connect the [EmbedderModel] parent to the nodes built in
      /// [buildEmbeddedModule].
      new Expanded(
        child: new AnimatedBuilder(
          animation: embedder,
          builder: _buildEmbeddedModule,
        ),
      ),
    ]..insert(isMyMessage ? 0 : 1, _buildToolbar());

    return new SizedBox(
      height: embedder.height,
      child: new Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  /// Builds a toolbar for refresh, delete buttons.
  Widget _buildToolbar() {
    return new Container(
        color: Colors.grey,
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            new IconButton(
              icon: new Icon(Icons.refresh),
              onPressed: onRefresh,
            ),
            new IconButton(
              icon: new Icon(Icons.delete),
              onPressed: onDelete,
            ),
          ],
        ));
  }

  @override
  bool get transparent => true;

  /// Command specific rendering, delelgates to the embedder for the mod
  /// command.
  Widget _buildEmbeddedModule(
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
