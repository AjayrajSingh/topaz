// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:chat_models/chat_models.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/widgets.dart';

/// A widget representing the people section of the info module.
class ParticipantsSection extends StatelessWidget {
  /// Indicates whether it is allowed to edit conversation membership.
  final bool editingEnabled;

  /// Called when the add button is tapped. Only works when the [editingEnabled]
  /// value is `true`.
  final VoidCallback onAddTapped;

  /// Called when the remove button is tapped for a participant. Only works when
  /// the [editingEnabled] value is `true`.
  final ValueChanged<Participant> onRemoveTapped;

  /// Creates a new instance of [ParticipantsSection].
  const ParticipantsSection({
    Key key,
    this.editingEnabled = false,
    this.onAddTapped,
    this.onRemoveTapped,
  })  : assert(editingEnabled != null),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return new ScopedModelDescendant<UserModel>(
      builder: (BuildContext context, Widget child, UserModel model) {
        ThemeData theme = Theme.of(context);

        List<Widget> children = <Widget>[
          new Padding(
            padding: const EdgeInsetsDirectional.only(start: 16.0),
            child: new Text('People', style: theme.textTheme.caption),
          ),
        ];

        if (editingEnabled) {
          children.add(new ListTile(
            leading: new Icon(Icons.add, size: 40.0),
            title: const Text('Add people'),
            onTap: onAddTapped,
          ));
        }

        if (model != null) {
          children.addAll(model.currentParticipants.map(_buildParticipantTile));
        }

        return new Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: new Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        );
      },
    );
  }

  Widget _buildParticipantTile(Participant participant) {
    Widget trailing;
    if (editingEnabled) {
      trailing = new IconButton(
        icon: new Icon(Icons.clear),
        onPressed:
            onRemoveTapped != null ? () => onRemoveTapped(participant) : null,
      );
    }

    return new ListTile(
      leading: new Alphatar.fromNameAndUrl(
        name: participant.effectiveDisplayName,
        avatarUrl: participant.photoUrl,
        size: 40.0,
      ),
      title: new Text(participant.effectiveDisplayName),
      trailing: trailing,
    );
  }
}
