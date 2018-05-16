// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui' as ui
    show Paragraph, ParagraphBuilder, ParagraphConstraints, ParagraphStyle;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'line_cache.dart';
import 'text_line.dart';
import 'xi_app.dart';

/// Widget for one editor tab
class Editor extends StatefulWidget {
  /// Standard widget constructor
  const Editor({Key key}) : super(key: key);

  @override
  EditorState createState() => new EditorState();
}

// Generated from data scraped from
// https://source.android.com/devices/input/keyboard-devices.html
Map<int, int> _androidToHid = <int, int>{
  0x001d: 0x0004,
  0x001e: 0x0005,
  0x001f: 0x0006,
  0x0020: 0x0007,
  0x0021: 0x0008,
  0x0022: 0x0009,
  0x0023: 0x000a,
  0x0024: 0x000b,
  0x0025: 0x000c,
  0x0026: 0x000d,
  0x0027: 0x000e,
  0x0028: 0x000f,
  0x0029: 0x0010,
  0x002a: 0x0011,
  0x002b: 0x0012,
  0x002c: 0x0013,
  0x002d: 0x0014,
  0x002e: 0x0015,
  0x002f: 0x0016,
  0x0030: 0x0017,
  0x0031: 0x0018,
  0x0032: 0x0019,
  0x0033: 0x001a,
  0x0034: 0x001b,
  0x0035: 0x001c,
  0x0036: 0x001d,
  0x0008: 0x001e,
  0x0009: 0x001f,
  0x000a: 0x0020,
  0x000b: 0x0021,
  0x000c: 0x0022,
  0x000d: 0x0023,
  0x000e: 0x0024,
  0x000f: 0x0025,
  0x0010: 0x0026,
  0x0007: 0x0027,
  0x0042: 0x0028,
  0x006f: 0x0029,
  0x0043: 0x002a,
  0x003d: 0x002b,
  0x003e: 0x002c,
  0x0045: 0x002d,
  0x0046: 0x002e,
  0x0047: 0x002f,
  0x0048: 0x0030,
  0x0049: 0x0031,
  0x004a: 0x0033,
  0x004b: 0x0034,
  0x0044: 0x0035,
  0x0037: 0x0036,
  0x0038: 0x0037,
  0x004c: 0x0038,
  0x0073: 0x0039,
  0x0083: 0x003a,
  0x0084: 0x003b,
  0x0085: 0x003c,
  0x0086: 0x003d,
  0x0087: 0x003e,
  0x0088: 0x003f,
  0x0089: 0x0040,
  0x008a: 0x0041,
  0x008b: 0x0042,
  0x008c: 0x0043,
  0x008d: 0x0044,
  0x008e: 0x0045,
  0x0078: 0x0046,
  0x0074: 0x0047,
  0x0079: 0x0048,
  0x007c: 0x0049,
  0x007a: 0x004a,
  0x005c: 0x004b,
  0x0070: 0x004c,
  0x007b: 0x004d,
  0x005d: 0x004e,
  0x0016: 0x004f,
  0x0015: 0x0050,
  0x0014: 0x0051,
  0x0013: 0x0052,
  0x008f: 0x0053,
  0x009a: 0x0054,
  0x009b: 0x0055,
  0x009c: 0x0056,
  0x009d: 0x0057,
  0x00a0: 0x0058,
  0x0091: 0x0059,
  0x0092: 0x005a,
  0x0093: 0x005b,
  0x0094: 0x005c,
  0x0095: 0x005d,
  0x0096: 0x005e,
  0x0097: 0x005f,
  0x0098: 0x0060,
  0x0099: 0x0061,
  0x0090: 0x0062,
  0x009e: 0x0063,
  0x0052: 0x0065,
  0x001a: 0x0066,
  0x00a1: 0x0067,
  0x0056: 0x0078,
  0x00a4: 0x007f,
  0x0018: 0x0080,
  0x0019: 0x0081,
  0x009f: 0x0085,
  0x00a2: 0x00b6,
  0x00a3: 0x00b7,
  0x0071: 0x00e0,
  0x003b: 0x00e1,
  0x0039: 0x00e2,
  0x0075: 0x00e3,
  0x0072: 0x00e4,
  0x003c: 0x00e5,
  0x003a: 0x00e6,
  0x0076: 0x00e7,
  0x0055: 0x00e8,
  0x0058: 0x00ea,
  0x0057: 0x00eb,
  0x0081: 0x00ec,
  0x0040: 0x00f0,
  0x0004: 0x00f1,
  0x007d: 0x00f2
};

// Android KeyEvent metaState values, names are capital in original
// ignore: constant_identifier_names
const int _META_ALT_LEFT_ON = 0x10;
// ignore: constant_identifier_names
const int _META_ALT_RIGHT_ON = 0x20;
// ignore: constant_identifier_names
const int _META_SHIFT_LEFT_ON = 0x40;
// ignore: constant_identifier_names
const int _META_SHIFT_RIGHT_ON = 0x80;
// ignore: constant_identifier_names
const int _META_CTRL_LEFT_ON = 0x2000;
// ignore: constant_identifier_names
const int _META_CTRL_RIGHT_ON = 0x4000;

// Fuchsia modifier values. See:
// //garnet/public/lib/ui/input/fidl/input_event_constants.fidl
const int _modifierShiftLeft = 2;
const int _modifierShiftRight = 4;
const int _modifierShiftMask = 6;
const int _modifierCtrlLeft = 8;
const int _modifierCtrlRight = 0x10;
const int _modifierCtrlMask = 0x18;
const int _modifierAltLeft = 0x20;
const int _modifierAltRight = 0x40;
// ignore: unused_element
const int _modifierAltMask = 0x60;
const int _modifierAltCtrlMask = 0x78;

/// A simple class representing a line and column location in the view.
class LineCol {
  /// Create a new location for the given line and column
  LineCol({this.line, this.col});

  /// The line number, 0-based
  final int line;

  /// The column, as a utf-8 offset from beginning of line
  final int col;
  @override
  String toString() {
    return 'line: $line, col: $col';
  }
}

const String _zeroWidthSpace = '\u{200b}';

/// State for editor tab
class EditorState extends State<Editor> {
  LineCache _lines;
  final ScrollController _controller = new ScrollController();
  // Height of lines (currently fixed, all lines have the same height)
  double _lineHeight;
  // location of last tap (used to expand selection on long press)
  LineCol _lastTapLocation;
  final FocusNode _focusNode = new FocusNode();
  TextStyle _defaultStyle;

  /// Creates a new editor state.
  EditorState() {
    Color color = const Color(0xFF000000);
    _defaultStyle = new TextStyle(color: color);
    // TODO: make style configurable
    _lineHeight = _lineHeightForStyle(_defaultStyle);
    _lines = new LineCache(_defaultStyle);
  }

  XiAppState get _xiAppState =>
      context.ancestorStateOfType(const TypeMatcher<XiAppState>());

  @override
  void initState() {
    super.initState();
    _xiAppState.connectEditor(this);
    scheduleMicrotask(_sendScrollViewport);
  }

  double _lineHeightForStyle(TextStyle style) {
    ui.ParagraphBuilder builder =
        new ui.ParagraphBuilder(new ui.ParagraphStyle())
          ..pushStyle(style.getTextStyle())
          ..addText(_zeroWidthSpace);
    ui.Paragraph layout = builder.build()
      ..layout(new ui.ParagraphConstraints(width: double.infinity));
    return layout.height;
  }

  double _measureWidth(String s) {
    TextSpan span = new TextSpan(text: s, style: _defaultStyle);
    TextPainter painter =
        new TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
    return painter.width;
  }

  /// Handler for "update" method from core
  void update(List<Map<String, dynamic>> ops) {
    setState(() => _lines.applyUpdate(ops));
  }

  /// Handler for "scroll_to" method from core
  void scrollTo(int line, int col) {
    if (_controller.hasClients) {
      ScrollPosition pos = _controller.position;
      double topY = line * _lineHeight;
      double botY = topY + _lineHeight;
      if (topY < pos.pixels) {
        pos.jumpTo(topY);
      } else if (botY > pos.pixels + pos.viewportDimension) {
        pos.jumpTo(botY - pos.viewportDimension);
      }
    }
  }

  // Send a notification to the core. If params are not given,
  // an empty array will be sent.
  // ignore: avoid_annotating_with_dynamic
  void _sendNotification(String method, [dynamic params]) {
    _xiAppState.sendNotification(method, params ?? <dynamic>[]);
  }

  int _metaStateToModifiers(int metaState) {
    int modifiers = 0;
    if ((metaState & _META_CTRL_LEFT_ON) != 0) {
      modifiers |= _modifierCtrlLeft;
    }
    if ((metaState & _META_CTRL_RIGHT_ON) != 0) {
      modifiers |= _modifierCtrlRight;
    }
    if ((metaState & _META_SHIFT_LEFT_ON) != 0) {
      modifiers |= _modifierShiftLeft;
    }
    if ((metaState & _META_SHIFT_RIGHT_ON) != 0) {
      modifiers |= _modifierShiftRight;
    }
    if ((metaState & _META_ALT_LEFT_ON) != 0) {
      modifiers |= _modifierAltLeft;
    }
    if ((metaState & _META_ALT_RIGHT_ON) != 0) {
      modifiers |= _modifierAltRight;
    }
    return modifiers;
  }

  void _doMovement(String direction, int modifiers) {
    bool modifySel = ((modifiers & _modifierShiftMask) != 0);
    // Note: the "and_modify_selection" part will probably become a parameter to the
    // movement method.
    String method = modifySel
        ? 'move_${direction}_and_modify_selection'
        : 'move_$direction';
    _sendNotification(method);
  }

  void _handleHidKey(int hidUsage, int modifiers) {
    if (hidUsage == 0x2A) {
      // Keyboard DELETE (Backspace)
      _sendNotification('delete_backward');
    } else if (hidUsage == 0x28) {
      // Keyboard Return (ENTER)
      _sendNotification('insert_newline');
    } else if ((modifiers & _modifierCtrlMask) != 0 && hidUsage == 0x04) {
      // Keyboard a
      _doMovement('to_beginning_of_paragraph', modifiers);
    } else if ((modifiers & _modifierCtrlMask) != 0 && hidUsage == 0x08) {
      // Keyboard e
      _doMovement('to_end_of_paragraph', modifiers);
    } else if ((modifiers & _modifierCtrlMask) != 0 && hidUsage == 0x0E) {
      // Keyboard k
      _sendNotification('delete_to_end_of_paragraph');
    } else if ((modifiers & _modifierCtrlMask) != 0 && hidUsage == 0x17) {
      // Keyboard t
      _sendNotification('transpose');
    } else if ((modifiers & _modifierCtrlMask) != 0 && hidUsage == 0x1C) {
      // Keyboard y
      _sendNotification('yank');
    } else if ((modifiers & _modifierCtrlMask) != 0 && hidUsage == 0x1D) {
      // Keyboard z
      if ((modifiers & _modifierShiftMask) != 0) {
        _sendNotification('redo');
      } else {
        _sendNotification('undo');
      }
    } else if (hidUsage == 0x3A) {
      // Keyboard F1
      _sendNotification('debug_rewrap');
    } else if (hidUsage == 0x3B) {
      // Keyboard F2
      _sendNotification('debug_wrap_width');
    } else if (hidUsage == 0x50) {
      // Keyboard LeftArrow
      _doMovement('left', modifiers);
    } else if (hidUsage == 0x4F) {
      // Keyboard RightArrow
      _doMovement('right', modifiers);
    } else if (hidUsage == 0x52) {
      // Keyboard UpArrow
      _doMovement('up', modifiers);
    } else if (hidUsage == 0x51) {
      // Keyboard DownArrow
      _doMovement('down', modifiers);
    } else if ((modifiers & _modifierAltRight) != 0 && hidUsage == 0x04) {
      // altgr-a inserts emoji, to test unicode ability
      _sendNotification('insert', <String, dynamic>{'chars': '\u{1f601}'});
    } else if ((modifiers & _modifierAltRight) != 0 && hidUsage == 0x0f) {
      // altgr-l inserts arabic lam, to test bidi ability
      _sendNotification('insert', <String, dynamic>{'chars': '\u{0644}'});
    }
  }

  void _handleCodePoint(int codePoint, int modifiers) {
    if (codePoint == 9) {
      _sendNotification('insert_tab');
    } else if (codePoint == 10) {
      _sendNotification('insert_newline');
    } else {
      String chars = new String.fromCharCode(codePoint);
      _sendNotification('insert', <String, dynamic>{'chars': chars});
    }
  }

  void _handleKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      RawKeyEventData data = event.data;
      if (data is RawKeyEventDataAndroid) {
        print(
            'codePoint=${data.codePoint}, metaState=${data.metaState}, keyCode=${data.keyCode}');
        int modifiers = _metaStateToModifiers(data.metaState);
        if (data.codePoint != 0) {
          _handleCodePoint(data.codePoint, modifiers);
        } else if (_androidToHid.containsKey(data.keyCode)) {
          _handleHidKey(_androidToHid[data.keyCode], modifiers);
        }
      } else if (data is RawKeyEventDataFuchsia) {
        print(
            'codePoint=${data.codePoint}, modifiers=${data.modifiers}, hidUsage=${data.hidUsage}');
        if (data.codePoint != 0 &&
            (data.modifiers & _modifierAltCtrlMask) == 0) {
          _handleCodePoint(data.codePoint, data.modifiers);
        } else {
          _handleHidKey(data.hidUsage, data.modifiers);
        }
      }
    }
  }

  void _requestKeyboard() {
    FocusScope.of(context).requestFocus(_focusNode);
  }

  LineCol _getLineColFromGlobal(Offset globalPosition) {
    RenderBox renderObject = context.findRenderObject();
    Offset local = renderObject.globalToLocal(globalPosition);
    double x = local.dx;
    double y = local.dy + _controller.offset;
    int line = y ~/ _lineHeight;
    int col = 0;
    Line text = _lines.getLine(line);
    if (text != null) {
      col = _utf16ToUtf8Offset(text.text.text, text.getIndexForHorizontal(x));
    }
    return new LineCol(line: line, col: col);
  }

  void _handleTapDown(TapDownDetails details) {
    _requestKeyboard();
    _lastTapLocation = _getLineColFromGlobal(details.globalPosition);
    _sendNotification('gesture', <String, dynamic>{
      'line': _lastTapLocation.line,
      'col': _lastTapLocation.col,
      'ty': 'point_select'
    });
  }

  void _handleLongPress() {
    if (_lastTapLocation != null) {
      _sendNotification('gesture', <String, dynamic>{
        'line': _lastTapLocation.line,
        'col': _lastTapLocation.col,
        'ty': 'word_select'
      });
    }
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    LineCol lineCol = _getLineColFromGlobal(details.globalPosition);
    _sendNotification('drag', <int>[lineCol.line, lineCol.col, 0, 1]);
  }

  void _sendScrollViewport() {
    if (_controller.hasClients) {
      ScrollPosition pos = _controller.position;
      int viewHeight = 1 + pos.viewportDimension ~/ _lineHeight;
      if (viewHeight == 1) {
        // TODO: horrible hack, remove when we reliably get viewport height
        viewHeight = 42;
      }
      int start = pos.pixels ~/ _lineHeight;
      // TODO: be less noisy, send only if changed
      _sendNotification('scroll', <int>[start, start + viewHeight]);
      print('sending scroll $start $viewHeight');
    }
  }

  /// Implement measure_widths rpc request, measuring the width of strings
  /// using the font used for text display.
  dynamic measureWidths(List<Map<String, dynamic>> params) {
    List<List<double>> result = <List<double>>[];
    for (Map<String, dynamic> req in params) {
      List<double> inner = <double>[];
      List<String> strings = req['strings'];
      for (String s in strings) {
        inner.add(_measureWidth(s));
      }
      result.add(inner);
    }
    return result;
  }

  TextLine _itemBuilder(BuildContext ctx, int ix) {
    Line line = _lines.getLine(ix);
    if (line == null) {
      _sendNotification('request_lines', <int>[ix, ix + 1]);
    }
    return new TextLine(
      // TODO: the string '[invalid]' is debug painting, replace with actual UX.
      line?.text ?? new TextSpan(text: '[invalid]', style: _lines.style),
      line?.cursor,
      line?.styles,
      _lineHeight,
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    FocusScope.of(context).reparentIfNeeded(_focusNode);
    return new RawKeyboardListener(
      focusNode: _focusNode,
      onKey: _handleKey,
      child: new GestureDetector(
        onTapDown: _handleTapDown,
        onLongPress: _handleLongPress,
        onHorizontalDragUpdate: _handleHorizontalDragUpdate,
        behavior: HitTestBehavior.opaque,
        child: new NotificationListener<ScrollUpdateNotification>(
          onNotification: (ScrollUpdateNotification update) {
            _sendScrollViewport();
            return true;
          },
          child: new ListView.builder(
            itemExtent: _lineHeight,
            itemCount: _lines.height,
            itemBuilder: _itemBuilder,
            controller: _controller,
          ),
        ),
      ),
    );
  }
}

/// Convert a UTF-16 offset within a string to the corresponding UTF-8 offset
int _utf16ToUtf8Offset(String s, int utf16Offset) {
  int utf8Ix = 0;
  int utf16Ix = 0;
  while (utf16Ix < utf16Offset) {
    int codeUnit = s.codeUnitAt(utf16Ix);
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
    utf16Ix++;
  }
  return utf8Ix;
}
