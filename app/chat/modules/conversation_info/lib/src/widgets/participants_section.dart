// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:chat_models/chat_models.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/widgets.dart';

/// A widget representing the people section of the info module.
class ParticipantsSection extends StatelessWidget {
  /// Called when the add button is tapped.
  final VoidCallback onAddTapped;

  /// Called when the remove button is tapped for a participant.
  final ValueChanged<Participant> onRemoveTapped;

  /// Creates a new instance of [ParticipantsSection].
  const ParticipantsSection({
    Key key,
    this.onAddTapped,
    this.onRemoveTapped,
  })
      : super(key: key);

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
          new ListTile(
            leading: new Icon(Icons.add, size: 40.0),
            title: const Text('Add people'),
            onTap: onAddTapped,
          ),
        ];
        if (model != null) {
          children.addAll(model.currentParticipants.map(_buildParticipantTile));
        }

        return new Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      },
    );
  }

  Widget _buildParticipantTile(Participant participant) {
    return new ListTile(
      leading: new Alphatar.fromNameAndUrl(
        name: participant.effectiveDisplayName,
        avatarUrl: participant.photoUrl,
        size: 40.0,
      ),
      title: new Text(participant.effectiveDisplayName),
      trailing: new IconButton(
        icon: new Icon(Icons.clear),
        onPressed:
            onRemoveTapped != null ? () => onRemoveTapped(participant) : null,
      ),
    );
  }
}
