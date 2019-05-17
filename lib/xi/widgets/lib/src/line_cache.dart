// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// A data structure for holding a cache of lines, and receiving incremental updates
// based on deltas from xi-core.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// One line in the editor view, with cursor and style information.
class Line {
  /// The text of the line
  final TextSpan text;

  /// A list of cursor locations (at utf-16 offset)
  final List<int> cursor;

  /// The style info, in triple format (start, end, styleId), where
  /// start and end are utf-16 offsets. Note that this is similar to
  /// the xi protocol triple format, but with absolute rather than
  /// relative offsets, and utf-16 rather than utf-8.
  final List<int> styles;

  /// Constructor
  Line(this.text, this.cursor, this.styles);

  /// Constructor, from json data (xi-core update protocol format)
  Line.fromJson(Map<String, dynamic> json, TextStyle style)
      : text = TextSpan(text: json['text'], style: style),
        cursor = _transformCursor(json['text'], json) ?? <int>[],
        styles = _transformStyles(json['text'], json) ?? <int>[];

  /// Update cursor and styles for a line, retaining text, using json
  /// from the xi-core "update" op
  Line updateFromJson(Map<String, dynamic> json) => Line(
        text,
        _transformCursor(text.text, json) ?? cursor,
        _transformStyles(text.text, json) ?? styles,
      );

  /// Return the utf-16 offset closest to the given horizontal position.
  // TODO: should conversion to utf-8 offset happen here or be caller's
  // responsibility?
  int getIndexForHorizontal(double horizontal) {
    TextPainter textPainter =
        TextPainter(text: text, textDirection: TextDirection.ltr)..layout();
    Offset offset = Offset(horizontal, 0.0);
    TextPosition pos = textPainter.getPositionForOffset(offset);
    return pos.offset;
  }

  @override
  String toString() {
    return '"$text" $cursor $styles';
  }
}

/// A cache containing lines of text
class LineCache {
  /// Creates a line cache.
  LineCache(this.style);

  /// The style for rendering the text.
  TextStyle style;

  // TODO: optimization for larger documents (run-lengths of invalid lines)
  // note: line is nullable, indicating an invalid line
  List<Line> _lines = <Line>[];

  /// Apply an update, in the json format of the xi-core update protocol
  void applyUpdate(List<Map<String, dynamic>> ops) {
    List<Line> newLines = <Line>[];
    int oldIx = 0;
    for (Map<String, dynamic> op in ops) {
      int n = op['n'];
      switch (op['op']) {
        case 'ins':
          for (Map<String, dynamic> line in op['lines']) {
            newLines.add(Line.fromJson(line, style));
          }
          break;
        case 'invalidate':
          for (int i = 0; i < n; i++) {
            newLines.add(null);
          }
          break;
        case 'copy':
          newLines.addAll(_lines.getRange(oldIx, oldIx + n));
          oldIx += n;
          break;
        case 'update':
          for (Map<String, dynamic> line in op['lines']) {
            Line oldLine = _lines[oldIx++];
            if (oldLine == null) {
              newLines.add(null);
            } else {
              newLines.add(oldLine.updateFromJson(line));
            }
          }
          break;
        case 'skip':
          oldIx += n;
          break;
        default:
          print('unknown update op $op');
          break;
      }
    }
    _lines = newLines;
  }

  /// The height, in other words the number of visible lines.
  int get height => _lines.length;

  /// Get a line. Returns null if line is invalid.
  Line getLine(int ix) {
    return ix < height ? _lines[ix] : null;
  }
}

/// Convert a UTF-8 offset within a string to the corresponding UTF-16 offset
int _utf8ToUtf16Offset(String s, int utf8Offset) {
  int result = 0;
  int utf8Ix = 0;
  while (utf8Ix < utf8Offset) {
    int codeUnit = s.codeUnitAt(result);
    if (codeUnit < 0x80) {
      utf8Ix += 1;
    } else if (codeUnit < 0x800) {
      utf8Ix += 2;
    } else if (codeUnit >= 0xDC00 && codeUnit < 0xE000) {
      // We count the leading surrogate as 3, trailing as 1, total 4
      utf8Ix += 1;
    } else {
      utf8Ix += 3;
    }
    result++;
  }
  return result;
}

// Transform a list of utf-8 offsets to utf-16 offsets
List<int> _transformCursor(String s, Map<String, dynamic> json) {
  List<dynamic> cursorList = json['cursor'];
  List<int> cursor = cursorList?.cast();
  return cursor
      ?.map((int offset) => _utf8ToUtf16Offset(s, offset))
      ?.toList();
}

// Convert style triples from utf-8 to utf-16 and relative to absolute offsets.
List<int> _transformStyles(String s, Map<String, dynamic> json) {
  List<dynamic> stylesList = json['styles'];
  List<int> styles = stylesList?.cast();
  if (styles == null) {
    return null;
  }
  List<int> result = <int>[];
  int ix = 0;
  for (int i = 0; i < styles.length; i += 3) {
    int start = ix + styles[i];
    int end = start + styles[i + 1];
    int styleId = styles[i + 2];
    result
      ..add(_utf8ToUtf16Offset(s, start))
      ..add(_utf8ToUtf16Offset(s, end))
      ..add(styleId);
    ix = end;
  }
  return result;
}
