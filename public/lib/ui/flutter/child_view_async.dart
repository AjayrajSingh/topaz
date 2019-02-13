// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:lib.app.dart/app_async.dart';
import 'package:fidl_fuchsia_sys/fidl_async.dart';
import 'package:fidl_fuchsia_math/fidl_async.dart' as fidl;
import 'package:fidl_fuchsia_ui_app/fidl_async.dart' as app;
import 'package:fidl_fuchsia_ui_viewsv1/fidl_async.dart';
import 'package:fidl_fuchsia_ui_viewsv1token/fidl_async.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:fidl/fidl.dart';
import 'package:meta/meta.dart';
import 'package:zircon/zircon.dart';

import 'mozart.dart';

export 'package:fidl_fuchsia_ui_viewsv1token/fidl_async.dart' show ViewOwner;

ViewContainerProxy _initViewContainer() {
  // Analyzer doesn't know Handle must be dart:zircon's Handle
  final Handle handle = ScenicStartupInfo.takeViewContainer();
  if (handle == null) {
    return null;
  }
  final ViewContainerProxy proxy = new ViewContainerProxy()
    ..ctrl.bind(new InterfaceHandle<ViewContainer>(new Channel(handle)))
    ..setListener(_ViewContainerListenerImpl.instance.createInterfaceHandle());

  assert(() {
    proxy.ctrl.whenClosed.then((_) async {
      print('ViewContainerProxy: closed');
    });
    return true;
  }());

  return proxy;
}

final ViewContainerProxy _viewContainer = _initViewContainer();

class _ViewContainerListenerImpl extends ViewContainerListener {
  final ViewContainerListenerBinding _binding =
      new ViewContainerListenerBinding();

  InterfaceHandle<ViewContainerListener> createInterfaceHandle() {
    return _binding.wrap(this);
  }

  static final _ViewContainerListenerImpl instance =
      new _ViewContainerListenerImpl();

  @override
  Future<Null> onChildAttached(int childKey, ViewInfo childViewInfo) async {
    ChildViewConnection connection = _connections[childKey];
    connection?._onAttachedToContainer(childViewInfo);
  }

  @override
  Future<Null> onChildUnavailable(int childKey) async {
    ChildViewConnection connection = _connections[childKey];
    connection?._onUnavailable();
  }

  final Map<int, ChildViewConnection> _connections =
      new HashMap<int, ChildViewConnection>();
}

typedef ChildViewConnectionCallback = void Function(
    ChildViewConnection connection);
void _emptyConnectionCallback(ChildViewConnection c) {}

/// A connection with a child view.
///
/// Used with the [ChildView] widget to display a child view.
class ChildViewConnection {
  ChildViewConnection(InterfaceHandle<ViewOwner> viewOwner,
      {ChildViewConnectionCallback onAvailable,
      ChildViewConnectionCallback onUnavailable})
      : this.fromViewHolderToken(
            new EventPair(viewOwner?.passChannel()?.passHandle()),
            onAvailable: onAvailable,
            onUnavailable: onUnavailable);

  ChildViewConnection.fromViewHolderToken(EventPair viewHolderToken,
      {ChildViewConnectionCallback onAvailable,
      ChildViewConnectionCallback onUnavailable})
      : _onAvailableCallback = onAvailable ?? _emptyConnectionCallback,
        _onUnavailableCallback = onUnavailable ?? _emptyConnectionCallback,
        _viewHolderToken = viewHolderToken {
    assert(_viewHolderToken != null);
  }

  factory ChildViewConnection.launch(String url, Launcher launcher,
      {InterfaceRequest<ComponentController> controller,
      InterfaceRequest<ServiceProvider> childServices,
      ChildViewConnectionCallback onAvailable,
      ChildViewConnectionCallback onUnavailable}) {
    final Services services = new Services();
    final LaunchInfo launchInfo =
        new LaunchInfo(url: url, directoryRequest: services.request());
    try {
      launcher.createComponent(launchInfo, controller);
      return new ChildViewConnection.connect(services,
          childServices: childServices,
          onAvailable: onAvailable,
          onUnavailable: onUnavailable);
    } finally {
      services.close();
    }
  }

  factory ChildViewConnection.connect(Services services,
      {InterfaceRequest<ServiceProvider> childServices,
      ChildViewConnectionCallback onAvailable,
      ChildViewConnectionCallback onUnavailable}) {
    final app.ViewProviderProxy viewProvider = new app.ViewProviderProxy();
    services.connectToService(viewProvider.ctrl);
    try {
      EventPairPair viewTokens = new EventPairPair();
      assert(viewTokens.status == ZX.OK);

      viewProvider.createView(viewTokens.second, childServices, null);
      return new ChildViewConnection.fromViewHolderToken(viewTokens.first,
          onAvailable: onAvailable, onUnavailable: onUnavailable);
    } finally {
      viewProvider.ctrl.close();
    }
  }

  final ChildViewConnectionCallback _onAvailableCallback;
  final ChildViewConnectionCallback _onUnavailableCallback;
  EventPair _viewHolderToken;

  static int _nextViewKey = 1;
  int _viewKey;

  ViewProperties _currentViewProperties;

  VoidCallback _onViewInfoAvailable;
  ViewInfo _viewInfo;
  ui.SceneHost _sceneHost;

  void _onAttachedToContainer(ViewInfo viewInfo) {
    assert(_viewInfo == null);
    _viewInfo = viewInfo;
    if (_onViewInfoAvailable != null) {
      _onViewInfoAvailable();
    }
    _onAvailableCallback(this);
  }

  void _onUnavailable() {
    _viewInfo = null;
    _onUnavailableCallback(this);
  }

  void _addChildToViewHost() {
    if (_viewContainer == null) {
      return;
    }
    assert(_attached);
    assert(_viewHolderToken != null);
    assert(_viewKey == null);
    assert(_viewInfo == null);
    assert(_sceneHost == null);

    final EventPairPair sceneTokens = new EventPairPair();
    assert(sceneTokens.status == ZX.OK);

    // Analyzer doesn't know Handle must be dart:zircon's Handle
    _sceneHost = new ui.SceneHost(sceneTokens.first.passHandle());
    _viewKey = _nextViewKey++;
    _viewContainer.addChild2(_viewKey, _viewHolderToken, sceneTokens.second);
    _viewHolderToken = null;
    assert(!_ViewContainerListenerImpl.instance._connections
        .containsKey(_viewKey));
    _ViewContainerListenerImpl.instance._connections[_viewKey] = this;
  }

  void _removeChildFromViewHost() {
    if (_viewContainer == null) {
      return;
    }
    assert(!_attached);
    assert(_viewHolderToken == null);
    assert(_viewKey != null);
    assert(_sceneHost != null);
    assert(_ViewContainerListenerImpl.instance._connections[_viewKey] == this);
    final EventPairPair viewTokens = new EventPairPair();
    assert(viewTokens.status == ZX.OK);
    _ViewContainerListenerImpl.instance._connections.remove(_viewKey);
    _viewHolderToken = viewTokens.first;
    _viewContainer.removeChild2(_viewKey, viewTokens.second);
    _viewKey = null;
    _viewInfo = null;
    _currentViewProperties = null;
    _sceneHost.dispose();
    _sceneHost = null;
  }

  /// Only call when the connection is available.
  void requestFocus() {
    if (_viewKey != null) {
      // TODO(SCN-1186): Use new mechanism to implement RequestFocus.
    }
  }

  // The number of render objects attached to this view. In between frames, we
  // might have more than one connected if we get added to a new render object
  // before we get removed from the old render object. By the time we get around
  // to computing our layout, we must be back to just having one render object.
  int _attachments = 0;
  bool get _attached => _attachments > 0;

  void _attach() {
    assert(_attachments >= 0);
    ++_attachments;
    if (_viewKey == null) {
      _addChildToViewHost();
    }
  }

  void _detach() {
    assert(_attached);
    --_attachments;
    scheduleMicrotask(_removeChildFromViewHostIfNeeded);
  }

  void _removeChildFromViewHostIfNeeded() {
    assert(_attachments >= 0);
    if (_attachments == 0 && _viewKey != null) {
      _removeChildFromViewHost();
    }
  }

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

    fidl.SizeF size = new fidl.SizeF(width: width, height: height);
    fidl.InsetF inset = new fidl.InsetF(
        top: insetTop, right: insetRight, bottom: insetBottom, left: insetLeft);
    ViewLayout viewLayout = new ViewLayout(size: size, inset: inset);
    final customFocusBehavior = new CustomFocusBehavior(allowFocus: focusable);
    return _currentViewProperties = new ViewProperties(
      viewLayout: viewLayout,
      customFocusBehavior: customFocusBehavior,
    );
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

class _RenderChildView extends RenderBox {
  /// Creates a child view render object.
  _RenderChildView({
    ChildViewConnection connection,
    bool hitTestable = true,
    bool focusable = true,
  })  : _connection = connection,
        _hitTestable = hitTestable,
        _focusable = focusable,
        assert(hitTestable != null);

  /// The child to display.
  ChildViewConnection get connection => _connection;
  ChildViewConnection _connection;
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

  /// Whether this child should be included during hit testing.
  bool get hitTestable => _hitTestable;
  bool _hitTestable;
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

  /// Whether this child should be able to recieve focus events
  bool get focusable => _focusable;
  bool _focusable;
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
  void detach() {
    if (_connection != null) {
      _connection._detach();
      assert(_connection._onViewInfoAvailable != null);
      _connection._onViewInfoAvailable = null;
    }
    super.detach();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  TextPainter _debugErrorMessage;

  double _width;
  double _height;

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
        _debugErrorMessage ??= new TextPainter(
            text: const TextSpan(
                text:
                    'Child views are supported only when running in Scenic.'));
        _debugErrorMessage.layout(minWidth: size.width, maxWidth: size.width);
      }
      return true;
    }());
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    assert(needsCompositing);
    if (_connection?._viewInfo != null) {
      context.addLayer(new ChildSceneLayer(
        offset: offset,
        width: _width,
        height: _height,
        sceneHost: _connection._sceneHost,
        hitTestable: hitTestable,
      ));
    }
    assert(() {
      if (_viewContainer == null) {
        context.canvas.drawRect(
            offset & size, new Paint()..color = const Color(0xFF0000FF));
        _debugErrorMessage.paint(context.canvas, offset);
      }
      return true;
    }());
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(
      new DiagnosticsProperty<ChildViewConnection>(
        'connection',
        connection,
      ),
    );
  }
}

/// A layer that represents content from another process.
class ChildSceneLayer extends Layer {
  /// Creates a layer that displays content rendered by another process.
  ///
  /// All of the arguments must not be null.
  ChildSceneLayer({
    this.offset = Offset.zero,
    this.width = 0.0,
    this.height = 0.0,
    this.sceneHost,
    this.hitTestable = true,
  });

  /// Offset from parent in the parent's coordinate system.
  Offset offset;

  /// The horizontal extent of the child, in logical pixels.
  double width;

  /// The vertical extent of the child, in logical pixels.
  double height;

  /// The host site for content rendered by the child.
  ui.SceneHost sceneHost;

  /// Whether this child should be included during hit testing.
  ///
  /// Defaults to true.
  bool hitTestable;

  @override
  ui.EngineLayer addToScene(ui.SceneBuilder builder,
      [Offset layerOffset = Offset.zero]) {
    builder.addChildScene(
      offset: offset + layerOffset,
      width: width,
      height: height,
      sceneHost: sceneHost,
      hitTestable: hitTestable,
    );
    return null;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description
      ..add(new DiagnosticsProperty<Offset>('offset', offset))
      ..add(new DoubleProperty('width', width))
      ..add(new DoubleProperty('height', height))
      ..add(new DiagnosticsProperty<ui.SceneHost>('sceneHost', sceneHost))
      ..add(new DiagnosticsProperty<bool>('hitTestable', hitTestable));
  }

  @override
  S find<S>(Offset regionOffset) => null;
}

/// A widget that is replaced by content from another process.
///
/// Requires a [MediaQuery] ancestor to provide appropriate media information to
/// the child.
@immutable
class ChildView extends LeafRenderObjectWidget {
  /// Creates a widget that is replaced by content from another process.
  ChildView({this.connection, this.hitTestable = true, this.focusable = true})
      : super(key: new GlobalObjectKey(connection));

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

  @override
  _RenderChildView createRenderObject(BuildContext context) {
    return new _RenderChildView(
      connection: connection,
      hitTestable: hitTestable,
      focusable: focusable,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderChildView renderObject) {
    renderObject
      ..connection = connection
      ..hitTestable = hitTestable
      ..focusable = focusable;
  }
}

class View {
  /// Provide services to Scenic throught |provider|.
  ///
  /// |services| should contain the list of service names offered by the
  /// |provider|.
  static void offerServiceProvider(
      InterfaceHandle<ServiceProvider> provider, List<String> services) {
    // Analyzer doesn't know Handle must be dart:zircon's Handle
    Scenic.offerServiceProvider(provider.passChannel().handle, services);
  }
}
