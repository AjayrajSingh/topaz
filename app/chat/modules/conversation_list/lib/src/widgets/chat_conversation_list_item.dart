// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import '../models.dart';
import 'chat_group_avatar.dart';
import 'constants.dart';
import 'time_util.dart';

/// UI Widget that represents a single chat conversation when viewing many chat
/// conversations in a list.
class ChatConversationListItem extends StatelessWidget {
  /// Conversation data model.
  final Conversation conversation;

  /// Callback fired when this item is selected.
  final VoidCallback onSelect;

  /// Callback fired when this item is long pressed.
  final VoidCallback onLongPress;

  /// Indicates whether this conversation is currently selected or not.
  final bool selected;

  /// Constructor
  ChatConversationListItem({
    Key key,
    @required this.conversation,
    this.onSelect,
    this.onLongPress,
    bool selected,
  })
      : assert(conversation != null),
        assert(conversation.participants != null),
        selected = selected ?? false,
        super(key: key);

  String get _participantNames => conversation.participants
      .map((User user) => user.name ?? user.email)
      .toList()
      .join(', ');

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    return new Material(
      color: selected ? kSelectedBgColor : theme.canvasColor,
      child: new ListTile(
        leading: new ChatGroupAvatar(
          users: conversation.participants,
          selected: selected,
        ),
        title: new Text(
          conversation.title ?? _participantNames,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: new Text(
          conversation.snippet ?? '',
          overflow: TextOverflow.ellipsis,
        ),
        trailing: new Text(
          conversation.timestamp != null
              ? relativeDisplayDate(date: conversation.timestamp)
              : '',
          style: new TextStyle(
            color: Colors.grey[500],
            fontSize: 12.0,
          ),
        ),
        onTap: onSelect,
        onLongPress: onLongPress,
      ),
    );
  }
}
