// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:fidl/fidl.dart' show InterfaceHandle;
import 'package:fidl_fuchsia_mem/fidl.dart' show Buffer;
import 'package:fidl_fuchsia_skia_skottie/fidl.dart' as skottie;
import 'package:fidl_fuchsia_sys/fidl.dart';
import 'package:fidl_fuchsia_ui_app/fidl.dart' show ViewProviderProxy;
import 'package:fidl_fuchsia_ui_gfx/fidl_async.dart'
    show ExportToken, ImportToken;
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fuchsia_scenic_flutter/child_view.dart' show ChildView;
import 'package:fuchsia_scenic_flutter/child_view_connection.dart'
    show ChildViewConnection;
import 'package:lib.app.dart/app.dart';
import 'package:meta/meta.dart';
import 'package:zircon/zircon.dart';

typedef LoadCallback = void Function(
    skottie.Status status, skottie.Player player);

/// A [Widget] that displays lottie animation in a scenic view.
class LottiePlayer extends StatefulWidget {
  /// The JSON data of the animation as a string.
  final String json;

  /// The background color.
  final Color backgroundColor;

  /// Called after animation is loaded.
  final LoadCallback onLoad;

  /// Loops the animation. Default [true].
  final bool loop;

  /// Starts playing the animation after loading. Default [true].
  final bool autoplay;

  /// Constructor.
  const LottiePlayer({
    @required this.json,
    this.backgroundColor = Colors.black,
    this.loop = true,
    this.autoplay = true,
    Key key,
    this.onLoad,
  }) : super(key: key);

  @override
  _LottiePlayerState createState() => new _LottiePlayerState();
}

class _LottiePlayerState extends State<LottiePlayer> {
  final ComponentControllerProxy _controller = ComponentControllerProxy();
  final skottie.LoaderProxy _loader = skottie.LoaderProxy();
  ChildViewConnection _connection;

  @override
  void initState() {
    super.initState();

    _launchViewer();
    _loadViewer();
  }

  @override
  void didUpdateWidget(LottiePlayer old) {
    super.didUpdateWidget(old);
    if (old.json == widget.json &&
        old.backgroundColor == widget.backgroundColor &&
        old.loop == widget.loop &&
        old.autoplay == widget.autoplay) {
      return;
    }

    _loadViewer();
  }

  @override
  void dispose() {
    _loader?.ctrl?.close();
    _controller?.ctrl?.close();
    _connection = null;

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChildView(
        connection: _connection,
        hitTestable: false,
        focusable: false,
      );

  void _launchViewer() {
    final startupContext = StartupContext.fromStartupInfo();
    final incomingServices = Services();

    final launcher = LauncherProxy();
    connectToService(startupContext.environmentServices, launcher.ctrl);
    launcher.createComponent(
      LaunchInfo(
        url: 'skottie_viewer',
        directoryRequest: incomingServices.request(),
      ),
      _controller.ctrl.request(),
    );
    launcher.ctrl.close();

    final viewTokens = EventPairPair();
    assert(viewTokens.status == ZX.OK);
    final viewHolderToken = ImportToken(value: viewTokens.first);
    final viewToken = ExportToken(value: viewTokens.second);

    final viewProvider = ViewProviderProxy();
    incomingServices.connectToService(viewProvider.ctrl);
    viewProvider.createView(viewToken.value, null, null);
    viewProvider.ctrl.close();

    incomingServices
      ..connectToService(_loader.ctrl)
      ..close();

    _connection = ChildViewConnection.fromImportToken(viewHolderToken);
  }

  void _loadViewer() {
    final SizedVmo vmo =
        SizedVmo.fromUint8List(Uint8List.fromList(widget.json.codeUnits));
    final options = skottie.Options(
      backgroundColor: widget.backgroundColor.value,
      loop: widget.loop,
      autoplay: widget.autoplay,
    );
    _loader.load(Buffer(vmo: vmo, size: vmo.size), options,
        (skottie.Status status, InterfaceHandle<skottie.Player> player) {
      widget.onLoad(status, skottie.PlayerProxy()..ctrl.bind(player));
    });
  }
}
