// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_sys/fidl_async.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:fuchsia_logger/logger.dart';
import 'package:meta/meta.dart';

import 'child_view_connection.dart';
import 'internal/_mozart.dart';

/// A widget that is replaced by content from another process.
///
/// Requires a [MediaQuery] ancestor to provide appropriate media information to
/// the child.
@immutable
class ChildView extends LeafRenderObjectWidget {
  /// A connection to the child whose content will replace this widget.
  final ChildViewConnection connection;

  /// Whether this child should be included during hit testing.
  ///
  /// Defaults to true.
  final bool hitTestable;

  /// Whether this child and its children should be allowed to receive focus.
  ///
  /// Defaults to true.
  final bool focusable;

  /// Creates a widget that is replaced by content from another process.
  ChildView({this.connection, this.hitTestable = true, this.focusable = true})
      : super(key: GlobalObjectKey(connection));

  @override
  RenderBox createRenderObject(BuildContext context) {
    return RenderChildView(
      connection: connection,
      hitTestable: hitTestable,
      focusable: focusable,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    if (renderObject is RenderChildView) {
      renderObject
        ..connection = connection
        ..hitTestable = hitTestable
        ..focusable = focusable;
    } else {
      log.warning('updateRenderObject was called with unknown renderObject: '
          '[$renderObject]');
    }
  }
}

/// TODO add documentation
class View {
  /// Provide services to Scenic through [provider].
  ///
  /// [services] should contain the list of service names offered by the
  /// [provider].
  static void offerServiceProvider(
      InterfaceHandle<ServiceProvider> provider, List<String> services) {
    // Analyzer doesn't know Handle must be dart:zircon's Handle
    Scenic.offerServiceProvider(provider.passChannel().handle, services);
  }
}
