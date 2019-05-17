// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia_logger/logger.dart';

import 'client.dart';
import 'handler_interface.dart';

typedef WithView = void Function(XiViewHandler viewId);

/// Receives RPC messages from core, parses them, and calls the appropriate
/// methods on [XiHandler].
class XiHandlerAdapter extends XiRpcHandler {
  final XiHandler _handler;

  XiHandlerAdapter(this._handler);

  /// Helper for null-checking views
  void withView(String viewId, WithView fn) {
    XiViewHandler view = _handler.getView(viewId);
    if (view != null) {
      fn(view);
    } else {
      log.warning('no view for id \'$viewId\'');
    }
  }

  @override
  void handleNotification(String method, dynamic params) {
    String viewId = params['view_id'];
    switch (method) {
      case 'update':
        Map<String, dynamic> update = params['update'];
        List<dynamic> opsList = update['ops'];
        List<Map<String, dynamic>> ops = opsList.cast();
        return withView(viewId, (view) => view.update(ops));
      case 'scroll_to':
        Map<String, dynamic> scrollInfo = params;
        int line = scrollInfo['line'];
        int col = scrollInfo['col'];
        return withView(viewId, (view) => view.scrollTo(line, col));
      default:
        log.warning('notification, unknown method $method, params=$params');
    }
  }

  @override
  dynamic handleRpc(String method, dynamic params) {
    switch (method) {
      case 'measure_width':
        return _handler.measureWidths(params);
        break;
      default:
        log.warning('rpc request, unknown method $method, params=$params');
    }
    return null;
  }
}
