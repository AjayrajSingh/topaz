// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

/// Widget that renders a row for a given contact entry (address, phone...)
/// This is meant to be inside the ContactDetailsGroup
/// The child of the contact entry must be provided itself as a Widget.
class ContactDetailsRow extends StatelessWidget {
  /// Main child to render for the contact entry
  final Widget child;

  /// Callback for when an contact entry is selected;
  final VoidCallback onSelect;

  /// Label text for contact entry
  final String label;

  /// Constructor
  ContactDetailsRow({
    Key key,
    @required this.child,
    this.label,
    this.onSelect,
  })
      : super(key: key) {
    assert(child != null);
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = <Widget>[
      child,
    ];

    if (label != null) {
      children.add(new Text(
        label,
        style: new TextStyle(
          color: Colors.grey[500],
          fontSize: 14.0,
        ),
      ));
    }

    return new InkWell(
      onTap: () {
        onSelect?.call();
      },
      child: new Container(
        padding: const EdgeInsets.only(
          bottom: 16.0,
        ),
        child: new Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}
