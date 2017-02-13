// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'xi_app.dart';
import 'line_cache.dart';

/// Widget for one editor tab
class Editor extends StatefulWidget {
  /// Standard widget constructor
  Editor({Key key}) : super(key: key);

  @override
  EditorState createState() => new EditorState();
}

// Generated from data scraped from
// https://source.android.com/devices/input/keyboard-devices.html
Map<int, int> _androidToHid = <int, int>{
  0x001d: 0x0004, 0x001e: 0x0005, 0x001f: 0x0006, 0x0020: 0x0007,
  0x0021: 0x0008, 0x0022: 0x0009, 0x0023: 0x000a, 0x0024: 0x000b,
  0x0025: 0x000c, 0x0026: 0x000d, 0x0027: 0x000e, 0x0028: 0x000f,
  0x0029: 0x0010, 0x002a: 0x0011, 0x002b: 0x0012, 0x002c: 0x0013,
  0x002d: 0x0014, 0x002e: 0x0015, 0x002f: 0x0016, 0x0030: 0x0017,
  0x0031: 0x0018, 0x0032: 0x0019, 0x0033: 0x001a, 0x0034: 0x001b,
  0x0035: 0x001c, 0x0036: 0x001d, 0x0008: 0x001e, 0x0009: 0x001f,
  0x000a: 0x0020, 0x000b: 0x0021, 0x000c: 0x0022, 0x000d: 0x0023,
  0x000e: 0x0024, 0x000f: 0x0025, 0x0010: 0x0026, 0x0007: 0x0027,
  0x0042: 0x0028, 0x006f: 0x0029, 0x0043: 0x002a, 0x003d: 0x002b,
  0x003e: 0x002c, 0x0045: 0x002d, 0x0046: 0x002e, 0x0047: 0x002f,
  0x0048: 0x0030, 0x0049: 0x0031, 0x004a: 0x0033,
  0x004b: 0x0034, 0x0044: 0x0035, 0x0037: 0x0036, 0x0038: 0x0037,
  0x004c: 0x0038, 0x0073: 0x0039, 0x0083: 0x003a, 0x0084: 0x003b,
  0x0085: 0x003c, 0x0086: 0x003d, 0x0087: 0x003e, 0x0088: 0x003f,
  0x0089: 0x0040, 0x008a: 0x0041, 0x008b: 0x0042, 0x008c: 0x0043,
  0x008d: 0x0044, 0x008e: 0x0045, 0x0078: 0x0046, 0x0074: 0x0047,
  0x0079: 0x0048, 0x007c: 0x0049, 0x007a: 0x004a, 0x005c: 0x004b,
  0x0070: 0x004c, 0x007b: 0x004d, 0x005d: 0x004e, 0x0016: 0x004f,
  0x0015: 0x0050, 0x0014: 0x0051, 0x0013: 0x0052, 0x008f: 0x0053,
  0x009a: 0x0054, 0x009b: 0x0055, 0x009c: 0x0056, 0x009d: 0x0057,
  0x00a0: 0x0058, 0x0091: 0x0059, 0x0092: 0x005a, 0x0093: 0x005b,
  0x0094: 0x005c, 0x0095: 0x005d, 0x0096: 0x005e, 0x0097: 0x005f,
  0x0098: 0x0060, 0x0099: 0x0061, 0x0090: 0x0062, 0x009e: 0x0063,
  0x0052: 0x0065, 0x001a: 0x0066, 0x00a1: 0x0067,
  0x0056: 0x0078, 0x00a4: 0x007f, 0x0018: 0x0080, 0x0019: 0x0081,
  0x009f: 0x0085, 0x00a2: 0x00b6, 0x00a3: 0x00b7, 0x0071: 0x00e0,
  0x003b: 0x00e1, 0x0039: 0x00e2, 0x0075: 0x00e3, 0x0072: 0x00e4,
  0x003c: 0x00e5, 0x003a: 0x00e6, 0x0076: 0x00e7, 0x0055: 0x00e8,
  0x0058: 0x00ea, 0x0057: 0x00eb, 0x0081: 0x00ec, 0x0040: 0x00f0,
  0x0004: 0x00f1, 0x007d: 0x00f2
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
// //apps/mozart/services/input/input_event_constants.fidl
const int _modifierShiftLeft = 2;
const int _modifierShiftRight = 4;
const int _modifierShiftMask = 6;
const int _modifierCtrlLeft = 8;
const int _modifierCtrlRight = 0x10;
const int _modifierCtrlMask = 0x18;
const int _modifierAltLeft = 0x20;
const int _modifierAltRight = 0x40;
const int _modifierAltMask = 0x60;
const int _modifierAltCtrlMask = 0x78;

/// State for editor tab
class EditorState extends State<Editor> {
  LineCache _lines = new LineCache();

  XiAppState get _xiAppState =>
    context.ancestorStateOfType(new TypeMatcher<XiAppState>());

  @override
  void initState() {
    super.initState();
    _xiAppState.connectEditor(this);
  }

  /// Handler for "update" method from core
  void update(List<Map<String, dynamic>> ops) {
    setState(() => _lines.applyUpdate(ops));
  }

  // Send a notification to the core. If params are not given,
  // an empty array will be sent.
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
    String method = modifySel ? 'move_${direction}_and_modify_selection' : 'move_$direction';
    _sendNotification(method);
  }

  void _handleHidKey(int hidUsage, int modifiers) {
    if (hidUsage == 0x2A) {  // Keyboard DELETE (Backspace)
      _sendNotification('delete_backward');
    } else if (hidUsage == 0x28) {  // Keyboard Return (ENTER)
      _sendNotification('insert_newline');
    } else if ((modifiers & _modifierCtrlMask) != 0 && hidUsage == 0x04) {  // Keyboard a
      _doMovement('to_beginning_of_paragraph', modifiers);
    } else if ((modifiers & _modifierCtrlMask) != 0 && hidUsage == 0x08) {  // Keyboard e
      _doMovement('to_end_of_paragraph', modifiers);
    } else if ((modifiers & _modifierCtrlMask) != 0 && hidUsage == 0x0E) {  // Keyboard k
      _sendNotification('delete_to_end_of_paragraph');
    } else if ((modifiers & _modifierCtrlMask) != 0 && hidUsage == 0x17) {  // Keyboard t
      _sendNotification('transpose');
    } else if ((modifiers & _modifierCtrlMask) != 0 && hidUsage == 0x1C) {  // Keyboard y
      _sendNotification('yank');
    } else if ((modifiers & _modifierCtrlMask) != 0 && hidUsage == 0x1D) {  // Keyboard z
      if ((modifiers & _modifierShiftMask) != 0) {
        _sendNotification('redo');
      } else {
        _sendNotification('undo');
      }
    } else if (hidUsage == 0x3A) {  // Keyboard F1
      _sendNotification('debug_rewrap');
    } else if (hidUsage == 0x50) { // Keyboard LeftArrow
      _doMovement('left', modifiers);
    } else if (hidUsage == 0x4F) { // Keyboard RightArrow
      _doMovement('right', modifiers);
    } else if (hidUsage == 0x52) { // Keyboard UpArrow
      _doMovement('up', modifiers);
    } else if (hidUsage == 0x51) { // Keyboard DownArrow
      _doMovement('down', modifiers);
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
        print('codePoint=${data.codePoint}, metaState=${data.metaState}, keyCode=${data.keyCode}');
        int modifiers = _metaStateToModifiers(data.metaState);
        if (data.codePoint != 0) {
          _handleCodePoint(data.codePoint, modifiers);
        } else if (_androidToHid.containsKey(data.keyCode)) {
          _handleHidKey(_androidToHid[data.keyCode], modifiers);
        }
      } else if (data is RawKeyEventDataFuchsia) {
        print('codePoint=${data.codePoint}, modifiers=${data.modifiers}, hidUsage=${data.hidUsage}');
        if (data.codePoint != 0 && (data.modifiers & _modifierAltCtrlMask) == 0) {
          _handleCodePoint(data.codePoint, data.modifiers);
        } else {
          _handleHidKey(data.hidUsage, data.modifiers);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = <Widget>[];
    int height = _lines.height;
    for (int i = 0; i < height; i++) {
      children.add(new Text(_lines.getLine(i)?.text ?? '[invalid]'));
    }
    Widget textCol = new Column(children: children);
    RawKeyboardListener keyListener = new RawKeyboardListener(
      focused: true,
      child: textCol,
      onKey: _handleKey,
    );
    return keyListener;
  }
}
