// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_math/fidl_async.dart' as fidl;
import 'package:fidl_fuchsia_ui_viewsv1/fidl_async.dart';
import 'package:fidl_fuchsia_ui_viewsv1token/fidl_async.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:zircon/zircon.dart';

import 'internal/_child_scene_layer.dart';
import 'internal/_mozart.dart';
import 'internal/_view_container_listener_impl.dart';

typedef ChildViewConnectionCallback = void Function(
    ChildViewConnection connection);

final ViewContainerProxy _viewContainer = _initViewContainer();

void _emptyConnectionCallback(ChildViewConnection c) {}

ViewContainerProxy _initViewContainer() {
  // Analyzer doesn't know Handle must be dart:zircon's Handle
  final Handle handle = ScenicStartupInfo.takeViewContainer();
  if (handle == null) {
    return null;
  }
  final ViewContainerProxy proxy = ViewContainerProxy()
    ..ctrl.bind(InterfaceHandle<ViewContainer>(Channel(handle)))
    ..setListener(ViewContainerListenerImpl().createInterfaceHandle());

  assert(() {
    proxy.ctrl.whenClosed.then((_) async {
      print('ViewContainerProxy: closed');
    });
    return true;
  }());

  return proxy;
}

/// A connection with a child view.
///
/// Used with the [ChildView] widget to display a child view.
class ChildViewConnection {
  static int _nextViewKey = 1;

  // TODO consider providing this API after MS-2293 is fixed
  // factory ChildViewConnection.launch(String url, Launcher launcher,
  //     {InterfaceRequest<ComponentController> controller,
  //     InterfaceRequest<ServiceProvider> childServices,
  //     ChildViewConnectionCallback onAvailable,
  //     ChildViewConnectionCallback onUnavailable}) {
  //   final Services services = Services();
  //   final LaunchInfo launchInfo =
  //       LaunchInfo(url: url, directoryRequest: services.request());
  //   try {
  //     launcher.createComponent(launchInfo, controller);
  //     return ChildViewConnection.connect(services,
  //         childServices: childServices,
  //         onAvailable: onAvailable,
  //         onUnavailable: onUnavailable);
  //   } finally {
  //     services.close();
  //   }
  // }

  // TODO consider providing this API after MS-2293 is fixed
  // factory ChildViewConnection.connect(Services services,
  //     {InterfaceRequest<ServiceProvider> childServices,
  //     ChildViewConnectionCallback onAvailable,
  //     ChildViewConnectionCallback onUnavailable}) {
  //   final ViewProviderProxy viewProvider = ViewProviderProxy();
  //   services.connectToService(viewProvider.ctrl);
  //   try {
  //     final InterfacePair<ViewOwner> viewOwner = InterfacePair<ViewOwner>();
  //     viewProvider.createView(viewOwner.passRequest(), childServices);
  //     return ChildViewConnection(viewOwner.passHandle(),
  //         onAvailable: onAvailable, onUnavailable: onUnavailable);
  //   } finally {
  //     viewProvider.ctrl.close();
  //   }
  // }

  final ChildViewConnectionCallback _onAvailableCallback;
  final ChildViewConnectionCallback _onUnavailableCallback;
  InterfaceHandle<ViewOwner> _viewOwner;

  int _viewKey;
  ViewProperties _currentViewProperties;

  VoidCallback _onViewInfoAvailable;

  ViewInfo _viewInfo;
  SceneHost _sceneHost;
  int _attachments = 0;

  /// inits [ChildViewConnection] object
  ChildViewConnection(this._viewOwner,
      {ChildViewConnectionCallback onAvailable,
      ChildViewConnectionCallback onUnavailable})
      : _onAvailableCallback = onAvailable ?? _emptyConnectionCallback,
        _onUnavailableCallback = onUnavailable ?? _emptyConnectionCallback,
        assert(_viewOwner != null);

  bool get _attached => _attachments > 0;

  /// TODO add documnetation
  void onAttachedToContainer(ViewInfo viewInfo) {
    assert(_viewInfo == null);
    _viewInfo = viewInfo;
    if (_onViewInfoAvailable != null) {
      _onViewInfoAvailable();
    }
    _onAvailableCallback(this);
  }

  /// TODO add documentation
  void onUnavailable() {
    _viewInfo = null;
    _onUnavailableCallback(this);
  }

  /// Only call when the connection is available.
  void requestFocus() {
    if (_viewKey != null) {
      _viewContainer.requestFocus(_viewKey);
    }
  }

  // The number of render objects attached to this view. In between frames, we
  // might have more than one connected if we get added to a render object
  // before we get removed from the old render object. By the time we get around
  // to computing our layout, we must be back to just having one render object.
  /// TODO add documentation
  void sendSizeChangeHintHack(
      double widthChangeFactor, double heightChangeFactor) {
    assert(_attached);
    assert(_attachments == 1);
    if (_viewKey == null) {
      return;
    }

    if (_viewContainer == null) {
      return;
    }

    _viewContainer.sendSizeChangeHintHack(
        _viewKey, widthChangeFactor, heightChangeFactor);
  }

  void _addChildToViewHost() {
    if (_viewContainer == null) {
      return;
    }
    assert(_attached);
    assert(_viewOwner != null);
    assert(_viewKey == null);
    assert(_viewInfo == null);
    assert(_sceneHost == null);
    final HandlePairResult pair = System.eventpairCreate();
    assert(pair.status == ZX.OK);
    _sceneHost = SceneHost(pair.first);
    _viewKey = _nextViewKey++;
    _viewContainer.addChild(_viewKey, _viewOwner, pair.second);
    _viewOwner = null;
    assert(!ViewContainerListenerImpl().containsConnectionForKey(_viewKey));
    ViewContainerListenerImpl().addConnectionForKey(_viewKey, this);
  }

  void _attach() {
    assert(_attachments >= 0);
    ++_attachments;
    if (_viewKey == null) {
      _addChildToViewHost();
    }
  }

  ViewProperties _createViewProperties(
      double width,
      double height,
      double insetTop,
      double insetRight,
      double insetBottom,
      double insetLeft,
      bool focusable) {
    if (_currentViewProperties != null &&
        _currentViewProperties.viewLayout.size.width == width &&
        _currentViewProperties.viewLayout.size.height == height &&
        _currentViewProperties.viewLayout.inset.top == insetTop &&
        _currentViewProperties.viewLayout.inset.right == insetRight &&
        _currentViewProperties.viewLayout.inset.bottom == insetBottom &&
        _currentViewProperties.viewLayout.inset.left == insetLeft &&
        (_currentViewProperties.customFocusBehavior == null ||
                _currentViewProperties.customFocusBehavior.allowFocus) ==
            focusable) {
      return null;
    }

    fidl.SizeF size = fidl.SizeF(width: width, height: height);
    fidl.InsetF inset = fidl.InsetF(
        top: insetTop, right: insetRight, bottom: insetBottom, left: insetLeft);
    ViewLayout viewLayout = ViewLayout(size: size, inset: inset);
    final customFocusBehavior = CustomFocusBehavior(allowFocus: focusable);
    return _currentViewProperties = ViewProperties(
      viewLayout: viewLayout,
      customFocusBehavior: customFocusBehavior,
    );
  }

  void _detach() {
    assert(_attached);
    --_attachments;
    scheduleMicrotask(_removeChildFromViewHostIfNeeded);
  }

  void _removeChildFromViewHost() {
    if (_viewContainer == null) {
      return;
    }
    assert(!_attached);
    assert(_viewOwner == null);
    assert(_viewKey != null);
    assert(_sceneHost != null);
    assert(ViewContainerListenerImpl().getConnectionForKey(_viewKey) == this);
    final ChannelPair pair = ChannelPair();
    assert(pair.status == ZX.OK);
    ViewContainerListenerImpl().removeConnectionForKey(_viewKey);
    _viewOwner = InterfaceHandle<ViewOwner>(pair.first);
    _viewContainer.removeChild(
        _viewKey, InterfaceRequest<ViewOwner>(pair.second));
    _viewKey = null;
    _viewInfo = null;
    _currentViewProperties = null;
    _sceneHost.dispose();
    _sceneHost = null;
  }

  void _removeChildFromViewHostIfNeeded() {
    assert(_attachments >= 0);
    if (_attachments == 0 && _viewKey != null) {
      _removeChildFromViewHost();
    }
  }

  void _setChildProperties(
    double width,
    double height,
    double insetTop,
    double insetRight,
    double insetBottom,
    double insetLeft,
    bool focusable,
  ) {
    assert(_attached);
    assert(_attachments == 1);
    assert(_viewKey != null);
    if (_viewContainer == null) {
      return;
    }
    ViewProperties viewProperties = _createViewProperties(
        width, height, insetTop, insetRight, insetBottom, insetLeft, focusable);
    if (viewProperties == null) {
      return;
    }
    _viewContainer.setChildProperties(_viewKey, viewProperties);
  }
}

/// TODO add documentation
class RenderChildView extends RenderBox {
  ChildViewConnection _connection;

  bool _hitTestable;
  bool _focusable;
  TextPainter _debugErrorMessage;

  double _width;
  double _height;

  /// Creates a child view render object.
  RenderChildView({
    ChildViewConnection connection,
    bool hitTestable = true,
    bool focusable = true,
  })  : _connection = connection,
        _hitTestable = hitTestable,
        _focusable = focusable,
        assert(hitTestable != null);

  @override
  bool get alwaysNeedsCompositing => true;

  /// The child to display.
  ChildViewConnection get connection => _connection;
  set connection(ChildViewConnection value) {
    if (value == _connection) {
      return;
    }
    if (attached && _connection != null) {
      _connection._detach();
      assert(_connection._onViewInfoAvailable != null);
      _connection._onViewInfoAvailable = null;
    }
    _connection = value;
    if (attached && _connection != null) {
      _connection._attach();
      assert(_connection._onViewInfoAvailable == null);
      _connection._onViewInfoAvailable = markNeedsPaint;
    }
    if (_connection == null) {
      markNeedsPaint();
    } else {
      markNeedsLayout();
    }
  }

  /// Whether this child should be able to recieve focus events
  bool get focusable => _focusable;

  set focusable(bool value) {
    assert(value != null);
    if (value == _focusable) {
      return;
    }
    _focusable = value;
    if (_connection != null) {
      markNeedsPaint();
    }
  }

  /// Whether this child should be included during hit testing.
  bool get hitTestable => _hitTestable;

  set hitTestable(bool value) {
    assert(value != null);
    if (value == _hitTestable) {
      return;
    }
    _hitTestable = value;
    if (_connection != null) {
      markNeedsPaint();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (_connection != null) {
      _connection._attach();
      assert(_connection._onViewInfoAvailable == null);
      _connection._onViewInfoAvailable = markNeedsPaint;
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(
      DiagnosticsProperty<ChildViewConnection>(
        'connection',
        connection,
      ),
    );
  }

  @override
  void detach() {
    if (_connection != null) {
      _connection._detach();
      assert(_connection._onViewInfoAvailable != null);
      _connection._onViewInfoAvailable = null;
    }
    super.detach();
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    assert(needsCompositing);
    if (_connection?._viewInfo != null) {
      context.addLayer(ChildSceneLayer(
        offset: offset,
        width: _width,
        height: _height,
        sceneHost: _connection._sceneHost,
        hitTestable: hitTestable,
      ));
    }
    assert(() {
      if (_viewContainer == null) {
        context.canvas
            .drawRect(offset & size, Paint()..color = const Color(0xFF0000FF));
        _debugErrorMessage.paint(context.canvas, offset);
      }
      return true;
    }());
  }

  @override
  void performLayout() {
    size = constraints.biggest;

    // Ignore if we have no child view connection.
    if (_connection == null) {
      return;
    }

    if (_width != null && _height != null) {
      double deltaWidth = (_width - size.width).abs();
      double deltaHeight = (_height - size.height).abs();

      // Ignore insignificant changes in size that are likely rounding errors.
      if (deltaWidth < 0.0001 && deltaHeight < 0.0001) {
        return;
      }
    }

    _width = size.width;
    _height = size.height;
    _connection._setChildProperties(
        _width, _height, 0.0, 0.0, 0.0, 0.0, _focusable);
    assert(() {
      if (_viewContainer == null) {
        _debugErrorMessage ??= TextPainter(
            text: const TextSpan(
                text:
                    'Child views are supported only when running in Scenic.'));
        _debugErrorMessage.layout(minWidth: size.width, maxWidth: size.width);
      }
      return true;
    }());
  }
}
