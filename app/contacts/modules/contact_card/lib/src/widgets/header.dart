// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/widgets.dart';

const double _kAvatarSize = 65.0;
const double _kHeaderFontSize = 16.0;

/// Header UI for a contact
class Header extends StatelessWidget {
  /// Contact display name
  final String displayName;

  /// Contact profile photo
  final String photoUrl;

  /// Constructor
  const Header({
    this.displayName,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    Container alphatarContainer = new Container(
      margin: const EdgeInsets.only(top: 50.0, bottom: 20.0),
      child: new Alphatar.fromNameAndUrl(
        name: displayName,
        avatarUrl: photoUrl,
        size: _kAvatarSize,
      ),
    );
    Text displayNameText = new Text(
      displayName,
      style: new TextStyle(
        color: Colors.grey[800],
        fontSize: _kHeaderFontSize,
        fontWeight: FontWeight.bold,
      ),
    );

    return new Container(
      height: 200.0,
      color: Colors.lightBlue[300],
      child: new Center(
        child: new Column(
          children: <Widget>[
            alphatarContainer,
            displayNameText,
          ],
        ),
      ),
    );
  }
}
