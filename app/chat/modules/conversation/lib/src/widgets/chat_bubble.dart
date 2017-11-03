// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:widget_explorer_meta/widgets_meta.dart';

import '../../fixtures.dart';

const Radius _kBubbleBorderRadius = const Radius.circular(24.0);
const Radius _kBubbleBorderSmallRadius = const Radius.circular(4.0);

/// The direction that the chat bubble is orientated
enum ChatBubbleOrientation {
  /// Chat bubble is on the left side of the screen
  left,

  /// Chat bubble is on the right side of the screen
  right,
}

/// UI Widget for a chat bubble
/// A [ChatBubble] has an orientation (left/right) usually based on who the
/// message belongs to (recipient/sender)
class ChatBubble extends StatelessWidget {
  /// Child widget to embed inside the ChatBubble
  final Widget child;

  /// Orientation of chat bubble
  /// Defaults to ChatBubbleOrientation.left
  final ChatBubbleOrientation orientation;

  /// Background color of chat bubble
  /// Defaults to the primary color of theme
  final Color backgroundColor;

  /// Indicates whether the message should fill the entire bubble area or not.
  final bool fillBubble;

  /// Called when the bubble is tapped.
  final GestureTapCallback onTap;

  /// Called when the bubble is long pressed.
  final GestureLongPressCallback onLongPress;

  /// Constructor
  const ChatBubble({
    Key key,
    ChatBubbleOrientation orientation,
    this.backgroundColor,
    bool fillBubble,
    this.onTap,
    this.onLongPress,
    @required @Generator(ChatConversationFixtures, 'sentenceText') this.child,
  })
      : assert(child != null),
        orientation = orientation ?? ChatBubbleOrientation.left,
        fillBubble = fillBubble ?? false,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    BorderRadius borderRadius;
    if (fillBubble) {
      borderRadius = const BorderRadius.all(_kBubbleBorderSmallRadius);
    } else if (orientation == ChatBubbleOrientation.left) {
      borderRadius = const BorderRadius.only(
        bottomLeft: _kBubbleBorderSmallRadius,
        bottomRight: _kBubbleBorderRadius,
        topLeft: _kBubbleBorderRadius,
        topRight: _kBubbleBorderRadius,
      );
    } else {
      borderRadius = const BorderRadius.only(
        bottomLeft: _kBubbleBorderRadius,
        bottomRight: _kBubbleBorderSmallRadius,
        topLeft: _kBubbleBorderRadius,
        topRight: _kBubbleBorderRadius,
      );
    }

    EdgeInsets padding;
    if (fillBubble) {
      padding = EdgeInsets.zero;
    } else {
      padding = const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0);
    }

    // If the background color is not provided, the background will default to
    // the current theme's primary color. In this case, make sure to use the
    // primaryTextTheme which contrasts with the primary color.
    Widget wrappedChild;
    if (backgroundColor == null) {
      wrappedChild = new DefaultTextStyle(
        style: theme.primaryTextTheme.body1,
        child: child,
      );
    } else {
      wrappedChild = child;
    }

    return new ClipRRect(
      borderRadius: borderRadius,
      child: new GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: new Container(
          padding: padding,
          margin: const EdgeInsets.only(bottom: 2.0),
          decoration: new BoxDecoration(
            color: backgroundColor ?? theme.primaryColor,
            borderRadius: borderRadius,
          ),
          child: wrappedChild,
        ),
      ),
    );
  }
}
