// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular/fidl_async.dart';
import 'service_connection.dart';

ComponentContextProxy _componentContextProxy;

/// Return the [ComponentContext] cached instance associated with the
/// currently running component.
@Deprecated(
    'This method should not be used, instead use the fuchsia_modular package')
ComponentContext getComponentContext() {
  if (_componentContextProxy != null) {
    return _componentContextProxy;
  }
  _componentContextProxy = ComponentContextProxy();

  //ignore: deprecated_member_use
  connectToEnvironmentService(_componentContextProxy);
  return _componentContextProxy;
}
