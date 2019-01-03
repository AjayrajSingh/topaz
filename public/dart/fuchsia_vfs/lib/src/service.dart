// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl/fidl.dart' as fidl;
import 'package:fidl_fuchsia_io/fidl_async.dart';
import 'package:zircon/zircon.dart';

import 'vnode.dart';

/// Function passed by service implementation which can be
/// used to serve connection over [request].
typedef Connector<T> = void Function(fidl.InterfaceRequest<T> request);

/// A node which binds a channel to a service implementation when opened.
class Service<T> extends Vnode {
  Connector<T> _connector;

  /// Constructor with [Connector]
  Service.withConnector(this._connector) : assert(_connector != null);

  @override
  int inodeNumber() {
    return inoUnknown;
  }

  @override
  int connect(int flags, int mode, fidl.InterfaceRequest<Node> request,
      [int parentFlags = -1]) {
    var status = _validateFlagsAndMode(flags, mode);
    if (status != ZX.OK) {
      sendErrorEvent(flags, status, request);
      return status;
    }
    _connector(fidl.InterfaceRequest(request.passChannel()));

    return ZX.OK;
  }

  @override
  int type() {
    return direntTypeService;
  }

  int _validateFlagsAndMode(int flags, int mode) {
    if ((mode & ~modeProtectionMask) & ~modeTypeService != 0) {
      return ZX.ERR_INVALID_ARGS;
    }
    if (flags & openFlagDirectory != 0) {
      return ZX.ERR_NOT_DIR;
    }

    // We don't support openRightDescribe, as service request is not going
    // to be of type fidl.InterfaceRequest<Node> most of the time, but we do send
    // OnOpen event incase of bad flags and if openRightDescribe is passed
    // so that underlying services don't need to handle these flags.
    var unsupportedFlags = ~(openRightReadable | openRightWritable);
    if (flags & unsupportedFlags != 0) {
      return ZX.ERR_NOT_SUPPORTED;
    }

    return ZX.OK;
  }
}
