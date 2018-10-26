// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:lib.app.dart/app.dart';
import 'package:fidl_fuchsia_sys/fidl.dart';
import 'package:fidl_fuchsia_math/fidl.dart' as fidl;
import 'package:fidl_fuchsia_ui_viewsv1/fidl.dart';
import 'package:fidl_fuchsia_ui_viewsv1token/fidl.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:fidl/fidl.dart';
import 'package:meta/meta.dart';
import 'package:zircon/zircon.dart';

import 'mozart.dart';

export 'package:fidl_fuchsia_ui_viewsv1token/fidl.dart' show ViewOwner;

ViewContainerProxy _initViewContainer() {
  // Analyzer doesn't know Handle must be dart:zircon's Handle
  final Handle handle = ScenicStartupInfo.takeViewContainer();
  if (handle == null) {
    return null;
  }
  final ViewContainerProxy proxy = new ViewContainerProxy()
    ..ctrl.bind(new InterfaceHandle<ViewContainer>(new Channel(handle)))
    ..setListener(_ViewContainerListenerImpl2.instance.createInterfaceHandle());

  assert(() {
    proxy.ctrl.error.then((ProxyError error) {
      print('ViewContainerProxy: error: $error');
    });
    return true;
  }());

  return proxy;
}

final ViewContainerProxy _viewContainer = _initViewContainer();

class _ViewContainerListenerImpl2 extends ViewContainerListener {
  final ViewContainerListenerBinding _binding =
      new ViewContainerListenerBinding();

  InterfaceHandle<ViewContainerListener> createInterfaceHandle() {
    return _binding.wrap(this);
  }

  static final _ViewContainerListenerImpl2 instance =
      new _ViewContainerListenerImpl2();

  @override
  void onChildAttached(int childKey, ViewInfo childViewInfo, void callback()) {
    ChildViewConnection2 connection = _connections[childKey];
    connection?._onAttachedToContainer(childViewInfo);
    callback();
  }

  @override
  void onChildUnavailable(int childKey, void callback()) {
    ChildViewConnection2 connection = _connections[childKey];
    connection?._onUnavailable();
    callback();
  }

  final Map<int, ChildViewConnection2> _connections =
      new HashMap<int, ChildViewConnection2>();
}

typedef ChildViewConnection2Callback = void Function(
    ChildViewConnection2 connection);
void _emptyConnectionCallback(ChildViewConnection2 c) {}

/// A connection with a child view.
///
/// Used with the [ChildView2] widget to display a child view.
class ChildViewConnection2 {
  ChildViewConnection2(this._viewOwner,
      {ChildViewConnection2Callback onAvailable,
      ChildViewConnection2Callback onUnavailable})
      : _onAvailableCallback = onAvailable ?? _emptyConnectionCallback,
        _onUnavailableCallback = onUnavailable ?? _emptyConnectionCallback,
        assert(_viewOwner != null);

  factory ChildViewConnection2.launch(String url, Launcher launcher,
      {InterfaceRequest<ComponentController> controller,
      InterfaceRequest<ServiceProvider> childServices,
      ChildViewConnection2Callback onAvailable,
      ChildViewConnection2Callback onUnavailable}) {
    final Services services = new Services();
    final LaunchInfo launchInfo =
        new LaunchInfo(url: url, directoryRequest: services.request());
    try {
      launcher.createComponent(launchInfo, controller);
      return new ChildViewConnection2.connect(services,
          childServices: childServices,
          onAvailable: onAvailable,
          onUnavailable: onUnavailable);
    } finally {
      services.close();
    }
  }

  factory ChildViewConnection2.connect(Services services,
      {InterfaceRequest<ServiceProvider> childServices,
      ChildViewConnection2Callback onAvailable,
      ChildViewConnection2Callback onUnavailable}) {
    final ViewProviderProxy viewProvider = new ViewProviderProxy();
    services.connectToService(viewProvider.ctrl);
    try {
      final InterfacePair<ViewOwner> viewOwner = new InterfacePair<ViewOwner>();
      viewProvider.createView(viewOwner.passRequest(), childServices);
      return new ChildViewConnection2(viewOwner.passHandle(),
          onAvailable: onAvailable, onUnavailable: onUnavailable);
    } finally {
      viewProvider.ctrl.close();
    }
  }

  final ChildViewConnection2Callback _onAvailableCallback;
  final ChildViewConnection2Callback _onUnavailableCallback;
  InterfaceHandle<ViewOwner> _viewOwner;

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
    assert(_viewOwner != null);
    assert(_viewKey == null);
    assert(_viewInfo == null);
    assert(_sceneHost == null);
    final HandlePairResult pair = System.eventpairCreate();
    assert(pair.status == ZX.OK);
    _sceneHost = new ui.SceneHost(pair.first);
    _viewKey = _nextViewKey++;
    _viewContainer.addChild(_viewKey, _viewOwner, pair.second);
    _viewOwner = null;
    assert(!_ViewContainerListenerImpl2.instance._connections
        .containsKey(_viewKey));
    _ViewContainerListenerImpl2.instance._connections[_viewKey] = this;
  }

  void _removeChildFromViewHost() {
    if (_viewContainer == null) {
      return;
    }
    assert(!_attached);
    assert(_viewOwner == null);
    assert(_viewKey != null);
    assert(_sceneHost != null);
    assert(_ViewContainerListenerImpl2.instance._connections[_viewKey] == this);
    final ChannelPair pair = new ChannelPair();
    assert(pair.status == ZX.OK);
    _ViewContainerListenerImpl2.instance._connections.remove(_viewKey);
    _viewOwner = new InterfaceHandle<ViewOwner>(pair.first);
    _viewContainer.removeChild(
        _viewKey, new InterfaceRequest<ViewOwner>(pair.second));
    _viewKey = null;
    _viewInfo = null;
    _currentViewProperties = null;
    _sceneHost.dispose();
    _sceneHost = null;
  }

  /// Only call when the connection is available.
  void requestFocus() {
    if (_viewKey != null) {
      _viewContainer.requestFocus(_viewKey);
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
        (_currentViewProperties.customFocusBehavior == null || _currentViewProperties.customFocusBehavior.allowFocus) == focusable) {
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

class _RenderChildView2 extends RenderBox {
  /// Creates a child view render object.
  _RenderChildView2({
    ChildViewConnection2 connection,
    bool hitTestable = true,
    bool focusable = true,
  })  : _connection = connection,
        _hitTestable = hitTestable,
        _focusable = focusable,
        assert(hitTestable != null);

  /// The child to display.
  ChildViewConnection2 get connection => _connection;
  ChildViewConnection2 _connection;
  set connection(ChildViewConnection2 value) {
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
    _connection._setChildProperties(_width, _height, 0.0, 0.0, 0.0, 0.0, _focusable);
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
      new DiagnosticsProperty<ChildViewConnection2>(
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
  ui.EngineLayer addToScene(ui.SceneBuilder builder, [Offset layerOffset = Offset.zero]) {
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
class ChildView2 extends LeafRenderObjectWidget {
  /// Creates a widget that is replaced by content from another process.
  ChildView2({this.connection, this.hitTestable = true, this.focusable = true})
      : super(key: new GlobalObjectKey(connection));

  /// A connection to the child whose content will replace this widget.
  final ChildViewConnection2 connection;

  /// Whether this child should be included during hit testing.
  ///
  /// Defaults to true.
  final bool hitTestable;

  /// Whether this child and its children should be allowed to receive focus.
  ///
  /// Defaults to true.
  final bool focusable;

  @override
  _RenderChildView2 createRenderObject(BuildContext context) {
    return new _RenderChildView2(
      connection: connection,
      hitTestable: hitTestable,
      focusable: focusable,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, _RenderChildView2 renderObject) {
    renderObject
      ..connection = connection
      ..hitTestable = hitTestable
      ..focusable = focusable;
  }
}

class View2 {
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
