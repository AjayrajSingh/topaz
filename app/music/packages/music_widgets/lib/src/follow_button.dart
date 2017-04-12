// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// Button for following/unfollowing Music entities, such as Artists, Albums &
/// Playlists
class FollowButton extends StatelessWidget {
  /// Callback for when this button is tapped
  final VoidCallback onTap;

  /// True if the authenticated user is currently following the entity
  final bool isFollowing;

  /// Highlight color used for this button
  ///
  /// Defaults to the theme primary color
  final Color highlightColor;

  /// Constructor
  FollowButton({
    Key key,
    this.onTap,
    this.isFollowing: false,
    this.highlightColor,
  })
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color _highlightColor = highlightColor ?? theme.primaryColor;
    return new Material(
      borderRadius: const BorderRadius.all(const Radius.circular(24.0)),
      color: isFollowing ? Colors.white : Colors.white.withAlpha(100),
      type: MaterialType.button,
      child: new InkWell(
        splashColor: isFollowing ? _highlightColor : Colors.white,
        onTap: () => onTap?.call(),
        child: new Container(
          width: 130.0,
          height: 40.0,
          child: new Center(
            child: new Text(
              isFollowing ? 'FOLLOWING' : 'FOLLOW',
              style: new TextStyle(
                color: isFollowing ? _highlightColor : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
