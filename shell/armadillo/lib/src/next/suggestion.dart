// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:armadillo/recent.dart';
import 'package:flutter/widgets.dart';
import 'package:fidl_images/fidl.dart';
import 'package:meta/meta.dart';

import 'suggestion_layout.dart';

/// Specifies the type of action to perform when the suggestion is selected.
enum SelectionType {
  /// [launchStory] will trigger the [Story] specified by
  /// [Suggestion.selectionStoryId] to come into focus.
  launchStory,

  /// [modifyStory] will modify the [Story] specified by
  /// [Suggestion.selectionStoryId] in some way.
  modifyStory,

  /// [doNothing] does nothing and is only provided for testing purposes.
  doNothing,

  /// [closeSuggestions] closes the suggestion overlay.
  closeSuggestions
}

/// Determines what the suggestion looks like with respect to
/// the image.
enum ImageType {
  /// An image of a person that is expected to be clipped as a circle.
  person,

  /// A non-person image
  other,
}

/// Determines what the suggestion looks like with respect to
/// the image.
enum ImageSide {
  /// The image should display to the right.
  right,

  /// The image should display to the left.
  left,
}

/// The unique id of a [Suggestion].
class SuggestionId extends ValueKey<String> {
  /// Constructor.
  const SuggestionId(String value) : super(value);
}

/// The model for displaying a suggestion in the suggestion overlay.
class Suggestion {
  /// The unique id of this suggestion.
  final SuggestionId id;

  /// Confidence of suggestion
  final double confidence;

  /// The suggestion's title.
  final String title;

  /// The suggestion's description.
  final String description;

  /// The color to use for the suggestion's background.
  final Color themeColor;

  /// The action to take when the suggestion is selected.
  final SelectionType selectionType;

  /// The story id related to this suggestion.
  final StoryId selectionStoryId;

  /// The main image of the suggestion.
  final EncodedImage image;

  /// List of icons URLs
  final List<EncodedImage> icons;

  /// The type of image.
  final ImageType imageType;

  SuggestionLayout _suggestionLayout;

  GlobalKey _suggestionKey;

  /// Constructor.
  Suggestion({
    @required this.id,
    this.confidence,
    this.title,
    this.description,
    this.themeColor,
    this.selectionType,
    this.selectionStoryId,
    this.image,
    this.imageType,
    this.icons,
  }) {
    _suggestionLayout = new SuggestionLayout(suggestion: this);
    _suggestionKey = new GlobalObjectKey(this);
  }

  /// How the suggestion should be laid out.
  SuggestionLayout get suggestionLayout => _suggestionLayout;

  @override
  int get hashCode => id.hashCode;

  @override
  bool operator ==(Object other) => other is Suggestion && other.id == id;

  @override
  String toString() => 'Suggestion(title: $title)';

  /// The global key to use when this suggestion is in a widget.
  GlobalKey get globalKey => _suggestionKey;
}
