// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:apps.mozart.services.input/ime_service.fidl.dart';
import 'package:flutter/material.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:meta/meta.dart';

import 'device_extender.dart';
import 'device_extension_state.dart';

/// A [SoftKeyboardContainer] which shows and hides a soft keyboard.
class SoftKeyboardContainerImpl extends SoftKeyboardContainer {
  final GlobalKey<_KeyboardDeviceExtensionState> _keyboardDeviceExtensionKey =
      new GlobalKey<_KeyboardDeviceExtensionState>();

  /// The connection to the IME.
  final ChildViewConnection _connection;

  /// Constructor.
  SoftKeyboardContainerImpl({
    @required InterfaceHandle<ViewOwner> softKeyboardView,
  })
      : _connection = new ChildViewConnection(softKeyboardView);

  @override
  void show(void callback(bool shown)) {
    _keyboardDeviceExtensionKey.currentState.show();
    callback(true);
  }

  @override
  void hide() {
    _keyboardDeviceExtensionKey.currentState.hide();
  }

  /// Wraps [child] in a [DeviceExtender] for displaying the soft keyboard.
  Widget wrap({Widget child}) => new DeviceExtender(
        deviceExtensions: <Widget>[
          new _KeyboardDeviceExtension(
            key: _keyboardDeviceExtensionKey,
            child: new Container(
              height: 256.0, // TODO(apwilson): This should be communicated to
              //                                me from the IME
              color: Colors.green[600],
              child: new ChildView(connection: _connection),
            ),
          )
        ],
        child: child,
      );
}

class _KeyboardDeviceExtension extends StatefulWidget {
  final Widget child;

  _KeyboardDeviceExtension({Key key, @required this.child}) : super(key: key);

  @override
  _KeyboardDeviceExtensionState createState() =>
      new _KeyboardDeviceExtensionState();
}

class _KeyboardDeviceExtensionState
    extends DeviceExtensionState<_KeyboardDeviceExtension> {
  @override
  Widget createWidget(BuildContext context) => new Container(
        color: Colors.black,
        child: widget.child,
      );
}
