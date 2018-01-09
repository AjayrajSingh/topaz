// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

/// Util functions for the Documents Browser

final DateFormat _kDateFormat = new DateFormat.yMMMMEEEEd();
const List<String> _kValidMimeTypes = const <String>[
  'image/',
  'video/',
  'application/pdf',
];

/// Formats the date into a word format, i.e. Day, Month Day, Year
String prettifyDate(int millisDate) {
  return _kDateFormat
      .format(new DateTime.fromMillisecondsSinceEpoch(millisDate));
}

/// Returns true if we have a thumbnail image location, and the file type is
/// an image or video.
bool showThumbnailImage(String thumbnailLocation, String mimeType) {
  if (thumbnailLocation.isNotEmpty) {
    for (String type in _kValidMimeTypes) {
      if (mimeType.startsWith(type)) {
        return true;
      }
    }
  }
  return false;
}

/// Shared Widgets for the Document Browser

/// Customizes a piece of text so that it is uppercase, left-aligned, and grey
class LabelText extends StatelessWidget {
  /// Text to customize
  final String text;

  /// Constructor
  const LabelText({
    Key key,
    @required this.text,
  })
      : assert(text != null),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return new Container(
      width: 100.0,
      child: new Text(
        text?.toUpperCase(),
        textAlign: TextAlign.left,
        style: new TextStyle(
          color: Colors.grey[500],
          fontSize: 10.0,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
