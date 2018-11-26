// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular/fidl_async.dart';
import 'service_connection.dart';

ComponentContextProxy _componentContextProxy;

/// Return the [ComponentContext] cached instance associated with the
/// currently running component.
ComponentContext getComponentContext() {
  if (_componentContextProxy != null) {
    return _componentContextProxy;
  }
  _componentContextProxy = ComponentContextProxy();
  connectToEnvironmentService(_componentContextProxy);
  return _componentContextProxy;
}
