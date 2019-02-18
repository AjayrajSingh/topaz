// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular/fidl_async.dart' as modular;
import 'package:fidl_fuchsia_ui_gfx/fidl_async.dart' as gfx;
import 'package:meta/meta.dart';

/// The result of calling [Module#embedModule] on the Module.
///
/// This object contains a reference to a [modular.ModuleController] as well as
/// a [gfx.ImportToken] object. The combination of these objects can be used to
/// embed the new module's view into your own view hierarchy.
class EmbeddedModule {
  /// The [modular.ModuleController] which can be used to control the embedded
  /// module.
  final modular.ModuleController moduleController;

  /// A token conferring ownership over a scenic View. This token can be used
  /// to embed the modules view into the UI and render its contents on the
  /// screen.
  final gfx.ImportToken viewHolderToken;

  /// Constructor
  EmbeddedModule({
    @required this.moduleController,
    @required this.viewHolderToken,
  })  : assert(moduleController != null),
        assert(viewHolderToken != null);
}
