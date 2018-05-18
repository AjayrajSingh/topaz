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
const int _kOneKilobyte = 1024;
const int _kOneMegabyte = _kOneKilobyte * 1024;
const int _kOneGigabyte = _kOneMegabyte * 1024;
const int _kOneTerabyte = _kOneGigabyte * 1024;

/// Formats the date into a word format, i.e. Day, Month Day, Year
String prettifyDate(int millisDate) {
  return _kDateFormat
      .format(new DateTime.fromMillisecondsSinceEpoch(millisDate));
}

/// Formats a file size in byte, KB, MB, GB, TB as appropriate
String prettifyFileSize(int bytes) {
  String suffix = 'bytes';
  double value = bytes.toDouble();
  if (bytes == 1) {
    return '1 byte';
  }
  if (bytes < _kOneKilobyte) {
    return '${bytes.toString()} bytes';
  }
  if (bytes < _kOneMegabyte) {
    suffix = 'KB';
    value = value / _kOneKilobyte;
  } else if (bytes < _kOneGigabyte) {
    suffix = 'MB';
    value = value / _kOneMegabyte;
  } else if (bytes < _kOneTerabyte) {
    suffix = 'GB';
    value = value / _kOneGigabyte;
  } else {
    suffix = 'TB';
    value = value / _kOneTerabyte;
  }
  return '${value.toStringAsFixed(value > 2.0 ? 0 : 1)} $suffix';
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
    @required this.text,
    Key key,
  })  : assert(text != null),
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
