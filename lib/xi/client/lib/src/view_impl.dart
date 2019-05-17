// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'client.dart';
import 'view_interface.dart';

/// An implementation of [XiViewProxy] that directly wraps a [XiClient].
class ViewProxy implements XiViewProxy {
  XiClient _inner;
  String _viewId;

  ViewProxy(this._inner, this._viewId);

  @override
  void insert(String text) {
    Map<String, dynamic> params = <String, dynamic>{
      'chars': text,
    };
    send('insert', params);
  }

  @override
  void insertTab() {
    send('insert_tab');
  }

  @override
  void insertNewline() {
    send('insert_newline');
  }

  @override
  void cancel() {
    send('cancel_operation');
  }

  @override
  void scroll(int first, int last) {
    List<int> params = <int>[first, last];
    send('scroll', params);
  }

  @override
  void resize(int width, int height) {
    Map<String, dynamic> params = <String, dynamic>{
      'width': width,
      'height': height,
    };
    send('resize', params);
  }

  @override
  void gesture(int line, int col, GestureType type) {
    String gestureString = gestureToString(type);
    Map<String, dynamic> params = <String, dynamic>{
      'line': line,
      'col': col,
      'ty': gestureString,
    };
    send('gesture', params);
  }

  @override
  void drag(int line, int col) {
    send('drag', <int>[line, col, 0, 1]);
  }

  @override
  Future<String> cut() {
    return cutCopy('cut');
  }

  @override
  Future<String> copy() {
    return cutCopy('copy');
  }

  Future<String> cutCopy(String method) {
    Map<String, dynamic> params = <String, dynamic>{
      'view_id': _viewId,
      'method': method,
    };
    return _inner.sendRpc('edit', params).then((data) => data);
  }

  @override
  void kill() {
    send('delete_to_end_of_paragraph');
  }

  @override
  void yank() {
    send('yank');
  }

  @override
  void undo() {
    send('undo');
  }

  @override
  void redo() {
    send('redo');
  }

  @override
  void requestLines(int first, int last) {
    send('request_lines', <int>[first, last]);
  }

  @override
  void deleteBackward() {
    send('delete_backward');
  }

  @override
  void deleteForward() {
    send('delete_forward');
  }

  @override
  void moveCursor(Movement movement) {
    String movementString = movementToString(movement);
    send(movementString);
  }

  @override
  void moveCursorModifyingSelection(Movement movement) {
    String movementString = movementToString(movement);
    send('${movementString}_and_modify_selection');
  }

  @override
  void scrollPageUp() {
    send('scroll_page_up');
  }

  @override
  void scrollPageDown() {
    send('scroll_page_down');
  }

  @override
  void uppercase() {
    send('uppercase');
  }

  @override
  void lowercase() {
    send('lowercase');
  }

  @override
  void indent() {
    send('indent');
  }

  @override
  void outdent() {
    send('outdent');
  }

  @override
  void transpose() {
    send('transpose');
  }

  void send(String method, [dynamic params = const <String, dynamic>{}]) {
    Map<String, dynamic> outerParams = <String, dynamic>{
      'view_id': _viewId,
      'method': method,
      'params': params,
    };
    _inner.sendNotification('edit', outerParams);
  }
}

/// Embedded views don't know about the concept of a 'viewId', and they can only
/// send 'edit' RPCs; this adapter avoids adding these fields. (They're added in
/// the session agent as needed.)
class EmbeddedViewProxy extends ViewProxy {
  EmbeddedViewProxy(XiClient _inner) : super(_inner, null);

  @override
  void send(String method, [dynamic params = const <String, dynamic>{}]) {
    _inner.sendNotification(method, params);
  }

  @override
  Future<String> cutCopy(String method) {
    return _inner
        .sendRpc(method, const <String, dynamic>{}).then((data) => data);
  }
}
