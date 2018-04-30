// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/widgets.dart';

/// A widget that provides a [child] widget when it's [Future] completes.
class FutureWidget extends StatefulWidget {
  /// Holds the [Future] or [Widget] instance.
  final FutureOr<Widget> child;

  /// Holds the [Widget] that is a place holder until [child] future completes.
  final Widget placeHolder;

  /// Constructor.
  const FutureWidget({this.child, this.placeHolder});

  @override
  _FutureWidgetState createState() => new _FutureWidgetState();
}

class _FutureWidgetState extends State<FutureWidget> {
  Widget _child;

  @override
  void initState() {
    super.initState();

    _initWidget();
  }

  @override
  void didUpdateWidget(FutureWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    _initWidget();
  }

  @override
  Widget build(BuildContext context) => _child;

  void _initWidget() {
    if (widget.child is Widget) {
      _child = widget.child;
    } else {
      // In case this state instance is reparented to another widget when the
      // future completes, cache the current parent widget.
      FutureWidget parentWidget = widget;
      _loadWidget(parentWidget.child, (Widget child) {
        if (parentWidget == widget && mounted) {
          setState(() => _child = child);
        }
      });
      _child = widget.placeHolder;
    }
  }

  void _loadWidget(Future<Widget> child, void callback(Widget widget)) {
    child.then(callback);
  }
}
