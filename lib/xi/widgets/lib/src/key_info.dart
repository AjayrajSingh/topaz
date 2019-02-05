// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/services.dart';

/// Convenience type for working with keyboard modifier masks.
class Modifiers {
  final int _modifiers;

  /// Create a new [Modifiers] instance from a fuchsia modifiers mask.
  Modifiers.fromFuchsia(this._modifiers);

  /// Create a new [Modifiers] instance from an android `metaState` bitmask.
  /// See [RawKeyEvent] for more background.
  Modifiers.fromAndroid(int metaState)
      : assert(int != null),
        _modifiers = _metaStateToModifiers(metaState);

  /// `true` if modifiers contain either control key.
  bool get ctrl => _modifiers & _modifierCtrlMask != 0;

  /// `true` if modifiers contain the right ctrl key.
  bool get ctrlRight => _modifiers & _modifierCtrlRight != 0;

  /// `true` if modifiers contain the left ctrl key.
  bool get ctrlLeft => _modifiers & _modifierCtrlLeft != 0;

  /// `true` if modifiers contain either alt key.
  bool get alt => _modifiers & _modifierAltMask != 0;

  /// `true` if modifiers contain the right alt key.
  bool get altRight => _modifiers & _modifierAltRight != 0;

  /// `true` if modifiers contain the left alt key.
  bool get altLeft => _modifiers & _modifierAltLeft != 0;

  /// `true` if modifiers contain both an alt and a ctrl key.
  bool get altCtrl => _modifiers & _modifierAltCtrlMask != 0;

  /// `true` if modifiers contain either shift key.
  bool get shift => _modifiers & _modifierShiftMask != 0;

  /// `true` if modifiers contain the right shift key.
  bool get shiftRight => _modifiers & _modifierShiftRight != 0;

  /// `true` if modifiers contain the left shift key.
  bool get shiftLeft => _modifiers & _modifierShiftLeft != 0;

  // Android KeyEvent htaState values, names are capital in original
  static const int _metaAltLeftOn = 0x10;
  static const int _metaAltRightOn = 0x20;
  static const int _metaShiftLeftOn = 0x40;
  static const int _metaShiftRightOn = 0x80;
  static const int _metaCtrlLeftOn = 0x2000;
  static const int _metaCtrlRightOn = 0x4000;

  // Fuchsia modifier values. See:
  // $garnet_sdk_fidl/fuchsia.ui.input/input_event_constants.fidl
  static const int _modifierShiftLeft = 2;
  static const int _modifierShiftRight = 4;
  static const int _modifierShiftMask = 6;
  static const int _modifierCtrlLeft = 8;
  static const int _modifierCtrlRight = 0x10;
  static const int _modifierCtrlMask = 0x18;
  static const int _modifierAltLeft = 0x20;
  static const int _modifierAltRight = 0x40;
  static const int _modifierAltMask = 0x60;
  static const int _modifierAltCtrlMask = 0x78;

  /// Convert an Android `metaState` mask into a Fuchsia modifier mask.
  static int _metaStateToModifiers(int metaState) {
    int modifiers = 0;
    if ((metaState & _metaCtrlLeftOn) != 0) {
      modifiers |= _modifierCtrlLeft;
    }
    if ((metaState & _metaCtrlRightOn) != 0) {
      modifiers |= _modifierCtrlRight;
    }
    if ((metaState & _metaShiftLeftOn) != 0) {
      modifiers |= _modifierShiftLeft;
    }
    if ((metaState & _metaShiftRightOn) != 0) {
      modifiers |= _modifierShiftRight;
    }
    if ((metaState & _metaAltLeftOn) != 0) {
      modifiers |= _modifierAltLeft;
    }
    if ((metaState & _metaAltRightOn) != 0) {
      modifiers |= _modifierAltRight;
    }
    return modifiers;
  }
}

/// Returns the HID key code corresponding to `androidKeyCode`, or `null` if
/// none exists. The caller is responsible for null checking.
///
/// This uses a lookup table generated from data scraped from
/// https://source.android.com/devices/input/keyboard-devices.html
///
/// NOTE: the original intention of the xi flutter client was to support android
/// in addition to fuchsia, so we retain the ability to handle android key events.
/// This has probably bit-rotted extensively, and could probably be removed.
int keyCodeFromAndroid(int androidKeyCode) {
  return _androidToHid[androidKeyCode];
}

const Map<int, int> _androidToHid = <int, int>{
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
