// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lib.module_resolver.fidl/daisy.fidl.dart';
import 'package:lib.widgets/model.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

import '../modular/embedder.dart';
import 'message.dart';

/// Enum for supported command types.
enum CommandType {
  /// Command to embed a mod.
  mod,
}

/// A [Message] model representing a slash command.
class CommandMessage extends Message {
  /// [Uuid] generator.
  static final Uuid uuid = new Uuid();

  /// Called whenever the [Model] changes.
  // CommandMessageParentBuilder parentBuilder;
  final Embedder embedder;

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

    // Supports "/mod <bin> <message>".
    if (_arguments.isNotEmpty) {
      String id = uuid.unparse(messageId);
      String bin = _arguments.first;

      Map<String, String> messageEntity = <String, String>{
        '@type': 'com.google.fuchsia.string',
        'content': _arguments.sublist(1).join(' '),
      };
      Map<String, dynamic> membersEntity = <String, dynamic>{
        '@type': 'com.google.fuchsia.chat.members',
        'members': members,
      };

      // Setup Daisy.
      Daisy daisy = new Daisy()
        ..verb = 'com.google.fuchsia.codelab.$bin'
        ..nouns = <String, Noun>{};
      daisy.nouns['message'] = new Noun()..json = JSON.encode(messageEntity);
      daisy.nouns['members'] = new Noun()..json = JSON.encode(membersEntity);

      embedder.startDaisy(
        daisy: daisy,
        name: id,
      );
    }
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
    return new ScopedModel<EmbedderModel>(
      model: embedder,
      child: new ScopedModelDescendant<EmbedderModel>(
          builder: buildEmbeddedModule),
    );
  }

  /// Command specific rendering, delelgates to the embedder for the mod
  /// command.
  Widget buildEmbeddedModule(
    BuildContext context,
    Widget child,
    EmbedderModel model,
  ) {
    if (_command == null) {
      return new Text(
        payload,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      );
    } else {
      return model.build(context);
    }
  }
}
