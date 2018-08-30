// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl/fidl.dart';

/// Provides a stubbed out subclass of [AsyncProxyController] which
/// aids in testing.
///
/// The object can be created with a given service name and interface
/// name and will return an invalid [InterfaceRequest] which is not intended
/// to be consumed.
class StubAsyncProxyController extends AsyncProxyController {
  /// The default constructor for this object.
  StubAsyncProxyController({
    String serviceName,
    String interfaceName,
  }) : super(
          $interfaceName: interfaceName,
          $serviceName: serviceName,
        );

  @override
  InterfaceRequest request() => InterfaceRequest(null);
}
