// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'client.dart';
import 'core_interface.dart';
import 'handler_adapter.dart';
import 'handler_interface.dart';
import 'view_impl.dart';
import 'view_interface.dart';

/// An implementation of [XiCoreProxy] wrapping any [XiClient].
class CoreProxy implements XiCoreProxy {
  XiClient _inner;

  CoreProxy(this._inner);

  set handler(XiHandler handler) {
    _inner.handler = XiHandlerAdapter(handler);
  }

  @override
  XiViewProxy view(String viewId) {
    return ViewProxy(_inner, viewId);
  }

  @override
  Future<Null> clientStarted() {
    return _inner.init().then((Null _) {
      _inner.sendNotification('client_started', <String, dynamic>{});
    });
  }

  @override
  Future<String> newView() {
    return _inner.sendRpc('new_view', <String, dynamic>{}).then((data) => data);
  }

  @override
  void closeView(String viewId) {
    Map<String, dynamic> params = <String, dynamic>{
      'view_id': viewId,
    };
    _inner.sendNotification('close_view', params);
  }

  @override
  void save(String viewId, {String path}) {
    Map<String, dynamic> params = <String, dynamic>{
      'view_id': viewId,
    };
    if (path != null) {
      params['file_path'] = path;
    }
    _inner.sendNotification('save', params);
  }
}
