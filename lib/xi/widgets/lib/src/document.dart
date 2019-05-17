// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xi_client/client.dart';

import 'editor.dart';
import 'line_cache.dart';

/// A notification called when the document has changed.
typedef DocumentChangeNotification = void Function(Document event);

/// Stores and manages updates to the state for a Xi document, and provides
/// access to the editing API to the [Editor], via the [XiViewProxy].
class Document extends Stream<Document> implements XiViewHandler {
  final LineCache lines = LineCache(TextStyle(color: Colors.black));

  final TextStyle _defaultStyle = TextStyle(color: Colors.white);

  /// A connection to xi-core.
  XiViewProxy _viewProxy;

  final StreamController<Document> _controller;

  Document() : _controller = StreamController.broadcast();

  List<Completer<XiViewProxy>> _pending = [];

  /// Provides access to the [XiViewProxy] via a [Future].
  ///
  /// Because view creation is asynchronous, we cannot get a handle to the
  /// [XiViewProxy] until after the document has been created. By returning
  /// a [Future], we allow the [Editor] to call edit API methods before the
  /// view has been resolved.
  Future<XiViewProxy> get viewProxy {
    if (_viewProxy != null) {
      return Future.value(_viewProxy);
    }
    final completer = Completer();
    _pending.add(completer);
    return completer.future;
  }

  // Assigns the XiViewProxy. This should only be called once,
  // by the root [XiHandler] when the 'new_view' request first resolves.
  void finalizeViewProxy(XiViewProxy newViewProxy) {
    assert(_viewProxy == null);
    _viewProxy = newViewProxy;
    for (var completer in _pending) {
      completer.complete(_viewProxy);
    }
    _pending = null;
    _notifyListeners();
  }

  LineCol _scrollPos = LineCol(line: 0, col: 0);
  LineCol get scrollPos => _scrollPos;

  double _measureWidth(String s) {
    TextSpan span = TextSpan(text: s, style: _defaultStyle);
    TextPainter painter =
        TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
    return painter.width;
  }

  List<List<double>> measureWidths(List<Map<String, dynamic>> params) {
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

  void _notifyListeners() {
    _controller.add(this);
  }

  void close() {
    _controller.close();
  }

  @override
  void scrollTo(int line, int col) {
    _scrollPos = LineCol(line: line, col: col);
    _notifyListeners();
  }

  @override
  void update(List<Map<String, dynamic>> params) {
    lines.applyUpdate(params);
    _notifyListeners();
  }

  @override
  StreamSubscription<Document> listen(void Function(Document event) onData,
      {Function onError, void Function() onDone, bool cancelOnError}) {
    scheduleMicrotask(_notifyListeners);
    return _controller.stream.listen(onData, onError: onError, onDone: onDone);
  }
}
