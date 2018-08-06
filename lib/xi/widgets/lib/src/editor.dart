// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui
    show Paragraph, ParagraphBuilder, ParagraphConstraints, ParagraphStyle;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:xi_client/client.dart';

import 'key_info.dart';
import 'line_cache.dart';
import 'text_line.dart';
import 'xi_app.dart';

/// Widget for one editor tab
class Editor extends StatefulWidget {
  /// If `true`, draws a watermark in the background of the editor view.
  final bool debugBackground;

  /// Standard widget constructor
  const Editor({Key key, this.debugBackground = false}) : super(key: key);

  @override
  EditorState createState() => new EditorState();
}

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
class EditorState extends State<Editor> implements XiViewHandler {
  XiViewProxy _viewProxy;

  /// Calls to core that were made before we were initialized are enqueued
  /// and sent on init.
  List<Completer<XiViewProxy>> _pending;
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
    _xiAppState.connectEditor(this).then((XiViewProxy viewProxy) {
      _viewProxy = viewProxy;
      _sendScrollViewport();
      if (_pending != null) {
        for (var completer in _pending) {
          completer.complete(_viewProxy);
        }
        _pending = null;
      }
    });
  }

  /// Returns a [Future] that will resolve when initialization has finished.
  Future<XiViewProxy> get viewProxy {
    if (_viewProxy != null) {
      return Future.value(_viewProxy);
    } else {
      Completer<XiViewProxy> completer = new Completer();
      _pending.add(completer);
      return completer.future;
    }
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
  @override
  void update(List<Map<String, dynamic>> ops) {
    setState(() => _lines.applyUpdate(ops));
  }

  /// Handler for "scroll_to" method from core
  @override
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

  void _doMovement(Movement movement, bool modifySel) {
    viewProxy.then((view) => modifySel
        ? view.moveCursorModifyingSelection(movement)
        : view.moveCursor(movement));
  }

  void _handleHidKey(int hidUsage, Modifiers modifiers) {
    if (hidUsage == 0x2A) {
      // Keyboard DELETE (Backspace)
      viewProxy.then((view) => view.deleteBackward());
    } else if (hidUsage == 0x28) {
      // Keyboard Return (ENTER)
      viewProxy.then((view) => view.insertNewline());
    } else if (modifiers.ctrl && hidUsage == 0x04) {
      // Keyboard a
      _doMovement(Movement.beginningOfParagraph, false);
    } else if (modifiers.ctrl && hidUsage == 0x08) {
      // Keyboard e
      _doMovement(Movement.endOfParagraph, false);
    } else if (modifiers.ctrl && hidUsage == 0x0E) {
      // Keyboard k
      viewProxy.then((view) => view.kill());
    } else if (modifiers.ctrl && hidUsage == 0x17) {
      // Keyboard t
      viewProxy.then((view) => view.transpose());
    } else if (modifiers.ctrl && hidUsage == 0x1C) {
      // Keyboard y
      viewProxy.then((view) => view.yank());
    } else if (modifiers.ctrl && hidUsage == 0x1D) {
      // Keyboard z
      if (modifiers.shift) {
        viewProxy.then((view) => view.redo());
      } else {
        viewProxy.then((view) => view.undo());
      }
    } else if (hidUsage == 0x50) {
      // Keyboard LeftArrow
      _doMovement(Movement.left, modifiers.shift);
    } else if (hidUsage == 0x4F) {
      // keyboard RightArrow
      _doMovement(Movement.right, modifiers.shift);
    } else if (hidUsage == 0x52) {
      // Keyboard UpArrow
      _doMovement(Movement.up, modifiers.shift);
    } else if (hidUsage == 0x51) {
      // Keyboard DownArrow
      _doMovement(Movement.down, modifiers.shift);
    } else if (modifiers.altRight && hidUsage == 0x04) {
      // altgr-a inserts emoji, to test unicode ability
      viewProxy.then((view) => view.insert('\u{1f601}'));
    } else if (modifiers.altRight && hidUsage == 0x0f) {
      // altgr-l inserts arabic lam, to test bidi ability
      viewProxy.then((view) => view.insert('\u{0644}'));
    }
  }

  void _handleCodePoint(int codePoint, Modifiers modifiers) {
    if (codePoint == 9) {
      viewProxy.then((view) => view.insertTab());
    } else if (codePoint == 10) {
      viewProxy.then((view) => view.insertNewline());
    } else {
      String chars = new String.fromCharCode(codePoint);
      viewProxy.then((view) => view.insert(chars));
    }
  }

  void _handleKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      RawKeyEventData data = event.data;
      if (data is RawKeyEventDataAndroid) {
        log.info(
            'codePoint=${data.codePoint}, metaState=${data.metaState}, keyCode=${data.keyCode}');
        var modifiers = Modifiers.fromAndroid(data.metaState);
        if (data.codePoint != 0) {
          _handleCodePoint(data.codePoint, modifiers);
        } else {
          int _hidKey = keyCodeFromAndroid(data.keyCode);
          if (_hidKey != null) {
            _handleHidKey(_hidKey, modifiers);
          }
        }
      } else if (data is RawKeyEventDataFuchsia) {
        log.info(
            'codePoint=${data.codePoint}, modifiers=${data.modifiers}, hidUsage=${data.hidUsage}');
        var modifiers = Modifiers.fromFuchsia(data.modifiers);
        if (data.codePoint != 0 && !modifiers.ctrl) {
          _handleCodePoint(data.codePoint, modifiers);
        } else {
          _handleHidKey(data.hidUsage, modifiers);
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
    GestureType gestureType = GestureType.pointSelect;
    viewProxy.then((view) =>
        view.gesture(_lastTapLocation.line, _lastTapLocation.col, gestureType));
  }

  void _handleLongPress() {
    if (_lastTapLocation != null) {
      GestureType gestureType = GestureType.pointSelect;
      viewProxy.then((view) => view.gesture(
          _lastTapLocation.line, _lastTapLocation.col, gestureType));
    }
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    LineCol lineCol = _getLineColFromGlobal(details.globalPosition);
    viewProxy.then((view) => view.drag(lineCol.line, lineCol.col));
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
      viewProxy.then((view) => view.scroll(start, start + viewHeight));
      log.info('sending scroll $start $viewHeight');
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
      viewProxy.then((view) => view.requestLines(ix, ix + 1));
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

    final lines = new ListView.builder(
      itemExtent: _lineHeight,
      itemCount: _lines.height,
      itemBuilder: _itemBuilder,
      controller: _controller,
    );

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
            child: new Container(
              color: Colors.white,
              constraints: BoxConstraints.expand(),
              child:
                  widget.debugBackground ? _makeDebugBackground(lines) : lines,
            )),
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

/// Creates a new widget with the editor overlayed on a watermarked background
Widget _makeDebugBackground(Widget editor) {
  return new Stack(children: <Widget>[
    Container(
        constraints: new BoxConstraints.expand(),
        child: new Center(
            child: Transform.rotate(
          angle: -math.pi / 6.0,
          child: new Text('xi editor',
              style: TextStyle(
                  fontSize: 144.0,
                  color: Colors.pink[50],
                  fontWeight: FontWeight.w800)),
        ))),
    editor,
  ]);
}
