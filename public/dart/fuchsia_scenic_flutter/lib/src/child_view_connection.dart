// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_math/fidl_async.dart';
import 'package:fidl_fuchsia_ui_gfx/fidl_async.dart' show ImportToken;
import 'package:fidl_fuchsia_ui_viewsv1/fidl_async.dart';
import 'package:fidl_fuchsia_ui_viewsv1token/fidl_async.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:zircon/zircon.dart';

import 'internal/_child_scene_layer.dart';
import 'view_container.dart' as shared;
import 'view_container_listener_impl.dart';

typedef ChildViewConnectionCallback = void Function(
    ChildViewConnection connection);

void _emptyConnectionCallback(ChildViewConnection c) {}

/// A connection with a child view.
///
/// Used with the [ChildView] widget to display a child view.
class ChildViewConnection implements ViewContainerListenerDelegate {
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
  // final app.ViewProviderProxy viewProvider = new app.ViewProviderProxy();
  // services.connectToService(viewProvider.ctrl);
  // try {
  //   EventPairPair viewTokens = new EventPairPair();
  //   assert(viewTokens.status == ZX.OK);

  //   viewProvider.createView(viewTokens.second, childServices, null);
  //   return new ChildViewConnection.fromViewHolderToken(viewTokens.first,
  //       onAvailable: onAvailable, onUnavailable: onUnavailable);
  //   } finally {
  //     viewProvider.ctrl.close();
  //   }
  // }

  final ChildViewConnectionCallback _onAvailableCallback;
  final ChildViewConnectionCallback _onUnavailableCallback;
  ImportToken _viewHolderToken;

  int _viewKey;
  ViewProperties _currentViewProperties;
  bool _available = false;

  VoidCallback _onViewInfoAvailable;

  SceneHost _sceneHost;
  int _attachments = 0;

  /// Deprecated.
  ChildViewConnection(InterfaceHandle<ViewOwner> viewOwner,
      {ChildViewConnectionCallback onAvailable,
      ChildViewConnectionCallback onUnavailable})
      : this.fromImportToken(
            ImportToken(
                value: EventPair(viewOwner?.passChannel()?.passHandle())),
            onAvailable: onAvailable,
            onUnavailable: onUnavailable);

  /// Constructs |ChildViewConnection| from a token.
  ChildViewConnection.fromViewHolderToken(EventPair viewHolderToken,
      {ChildViewConnectionCallback onAvailable,
      ChildViewConnectionCallback onUnavailable})
      : this.fromImportToken(ImportToken(value: viewHolderToken),
            onAvailable: onAvailable, onUnavailable: onUnavailable);

  /// Constructs |ChildViewConnection| from a token.
  ChildViewConnection.fromImportToken(ImportToken viewHolderToken,
      {ChildViewConnectionCallback onAvailable,
      ChildViewConnectionCallback onUnavailable})
      : _onAvailableCallback = onAvailable ?? _emptyConnectionCallback,
        _onUnavailableCallback = onUnavailable ?? _emptyConnectionCallback,
        _viewHolderToken = viewHolderToken {
    assert(_viewHolderToken?.value != null);
  }

  bool get _attached => _attachments > 0;

  /// TODO add documnetation
  @override
  void onAvailable() {
    _available = true;
    if (_onViewInfoAvailable != null) {
      _onViewInfoAvailable();
    }
    _onAvailableCallback(this);
  }

  /// TODO add documentation
  @override
  void onUnavailable() {
    _available = false;
    _onUnavailableCallback(this);
  }

  /// Only call when the connection is available.
  void requestFocus() {
    if (_viewKey != null) {
      // TODO(SCN-1186): Use new mechanism to implement RequestFocus.
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

    if (shared.globalViewContainer == null) {
      return;
    }

    shared.globalViewContainer.sendSizeChangeHintHack(
        _viewKey, widthChangeFactor, heightChangeFactor);
  }

  void _addChildToViewHost() {
    if (shared.globalViewContainer == null) {
      return;
    }
    assert(_attached);
    assert(_viewHolderToken.value.isValid);
    assert(_viewKey == null);
    assert(!_available);
    assert(_sceneHost == null);

    final EventPairPair sceneTokens = new EventPairPair();
    assert(sceneTokens.status == ZX.OK);

    // Analyzer doesn't know Handle must be dart:zircon's Handle
    _sceneHost = new SceneHost(sceneTokens.first.passHandle());
    _viewKey = shared.nextGlobalViewKey();
    shared.globalViewContainer
        .addChild2(_viewKey, _viewHolderToken.value, sceneTokens.second);
    _viewHolderToken = ImportToken(value: EventPair(null));
    assert(
        !ViewContainerListenerImpl.instance.containsConnectionForKey(_viewKey));
    ViewContainerListenerImpl.instance.addConnectionForKey(_viewKey, this);
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

    SizeF size = SizeF(width: width, height: height);
    InsetF inset = InsetF(
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
    if (shared.globalViewContainer == null) {
      return;
    }
    assert(_viewHolderToken != null);
    assert(_viewHolderToken.value != null);
    assert(!_attached);
    assert(!_viewHolderToken.value.isValid);
    assert(_viewKey != null);
    assert(_sceneHost != null);
    assert(ViewContainerListenerImpl.instance.getConnectionForKey(_viewKey) ==
        this);
    final EventPairPair viewTokens = new EventPairPair();
    assert(viewTokens.status == ZX.OK);
    ViewContainerListenerImpl.instance.removeConnectionForKey(_viewKey);
    _viewHolderToken = ImportToken(value: viewTokens.first);
    shared.globalViewContainer.removeChild2(_viewKey, viewTokens.second);
    _viewKey = null;
    _available = false;
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
    if (shared.globalViewContainer == null) {
      return;
    }
    ViewProperties viewProperties = _createViewProperties(
        width, height, insetTop, insetRight, insetBottom, insetLeft, focusable);
    if (viewProperties == null) {
      return;
    }
    shared.globalViewContainer.setChildProperties(_viewKey, viewProperties);
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
    if (_connection?._available == true) {
      context.addLayer(ChildSceneLayer(
        offset: offset,
        width: _width,
        height: _height,
        sceneHost: _connection._sceneHost,
        hitTestable: hitTestable,
      ));
    }
    assert(() {
      if (shared.globalViewContainer == null) {
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
      if (shared.globalViewContainer == null) {
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
