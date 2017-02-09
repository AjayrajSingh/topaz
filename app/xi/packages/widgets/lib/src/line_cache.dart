// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// A data structure for holding a cache of lines, and receiving incremental updates
// based on deltas from xi-core.

/// One line in the editor view, with cursor and style information
class Line {
  /// The text of the line
  final String text;
  /// A list of cursor locations (at utf-8 offset)
  final List<int> cursor;
  /// The style info, in the xi-core update protocol triple format
  final List<int> styles;

  /// Constructor
  Line(this.text, this.cursor, this.styles);

  /// Constructor, from json data (xi-core update protocol format)
  Line.fromJson(Map<String, dynamic> json)
    : text = json['text'],
      cursor = json['cursor'] ?? <int>[],
      styles = json['styles'] ?? <int>[];

  /// Update cursor and styles for a line, retaining text, using json
  /// from the xi-core "update" op
  Line updateFromJson(Map<String, dynamic> json) =>
    new Line(text, json['cursor'] ?? cursor, json['styles'] ?? styles);

  @override
  String toString() {
    return '"$text" $cursor $styles';
  }
}

/// A cache containing lines
class LineCache {
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
            newLines.add(new Line.fromJson(line));
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
    print('update result: $_lines');
  }

  /// The height, in other words the number of visible lines
  int get height => _lines.length;

  /// Get a line. Returns null if line is invalid
  Line getLine(int ix) {
    return _lines[ix];
  }
}
