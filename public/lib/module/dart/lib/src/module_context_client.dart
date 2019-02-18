// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl.dart' as fidl;
import 'package:fidl_fuchsia_ui_gfx/fidl_async.dart';
import 'package:fidl_fuchsia_ui_viewsv1token/fidl.dart';
import 'package:fuchsia_scenic_flutter/child_view.dart' show ChildView;
import 'package:fuchsia_scenic_flutter/child_view_connection.dart'
    show ChildViewConnection;
import 'package:lib.app.dart/logging.dart';
import 'package:lib.component.dart/component.dart';
import 'package:lib.story.dart/story.dart';
import 'package:meta/meta.dart';
import 'package:zircon/zircon.dart';

import 'module_controller_client.dart';

export 'package:lib.component.dart/component.dart' show ComponentContextClient;

/// When Module resolution fails.
class ResolutionException implements Exception {
  /// Information about the failure.
  final String message;

  /// Create a new [ResolutionException].
  ResolutionException(this.message);
}

/// Holds values necessary for interacting with Model and View related FIDL APIs
/// for modules started via [ModuleContextClient#embedModule].
class EmbeddedModule {
  /// The client for the ModuleController FIDL service connected to an embedded
  /// module.
  final ModuleControllerClient controller;

  /// The underlying ChildViewConnection, stored as a value here to prevent GC.
  final ChildViewConnection connection;

  /// The Flutter Widget that renders the UI of the started module. Do not
  /// assume the view is ready to display pixels to this view, check the
  /// controller to prevent jank.
  final ChildView view;

  /// Constructor, for usage see [ModuleContextClient#embedModule].
  EmbeddedModule({
    @required this.controller,
    @required this.connection,
    @required this.view,
  })  : assert(controller != null),
        assert(connection != null),
        assert(view != null);
}

/// Client wrapper for [fidl.ModuleContext].
///
/// TODO(SO-1125): implement all methods for ModuleContextClient
class ModuleContextClient {
  ComponentContextClient _componentContext;
  final OngoingActivityProxy _ongoingActivityProxy = new OngoingActivityProxy();

  /// The underlying [Proxy] used to send client requests to the
  /// [fidl.ModuleContext] service.
  final fidl.ModuleContextProxy proxy = new fidl.ModuleContextProxy();
  final List<LinkClient> _links = <LinkClient>[];

  /// Constructor.
  ModuleContextClient() {
    proxy.ctrl
      ..onBind = _handleBind
      ..onClose = _handleClose
      ..onConnectionError = _handleConnectionError
      ..onUnbind = _handleUnbind;
  }

  final Completer<Null> _bind = new Completer<Null>();

  /// A future that completes when the [proxy] is bound.
  Future<Null> get bound => _bind.future;

  void _handleBind() {
    log.fine('proxy ready');
    _bind.complete(null);
  }

  /// Connects the passed in [LinkClient] via [fidl.ModuleContextProxy#getLink].
  // TODO(MS-1245): retrun an active link client automatically instead of passing one
  // through.
  Future<Null> getLink({
    @required LinkClient linkClient,
  }) async {
    log.fine('getLink: ${linkClient.name}');

    // Track all the link clients so they can be closed automatically when this
    // client is.
    _links.add(linkClient);

    Completer<Null> completer = new Completer<Null>();

    try {
      await bound;
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
      return completer.future;
    }

    InterfaceRequest<Link> request;
    try {
      // NOTE: Any async errors on the link's proxy should be managed by
      // LinkClient.
      request = linkClient.proxy.ctrl.request();
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
      return completer.future;
    }

    try {
      proxy.getLink(linkClient.name, request);
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }

    scheduleMicrotask(() {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    return completer.future;
  }

  /// See [fidl.ComponentContext#getComponentContext].
  Future<ComponentContextClient> getComponentContext() async {
    await bound;

    if (_componentContext != null) {
      return _componentContext;
    } else {
      _componentContext = new ComponentContextClient();
    }

    Completer<ComponentContextClient> completer =
        new Completer<ComponentContextClient>();

    // ignore: unawaited_futures
    proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    // ignore: unawaited_futures
    _componentContext.proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    try {
      proxy.getComponentContext(_componentContext.proxy.ctrl.request());
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }

    scheduleMicrotask(() {
      if (!completer.isCompleted) {
        completer.complete(_componentContext);
      }
    });

    return completer.future;
  }

  /// See [fidl.ModuleContext#addModuleToStory].
  Future<ModuleControllerClient> addModuleToStory({
    @required String module,
    @required Intent intent,
    @required SurfaceRelation surfaceRelation,
  }) async {
    assert(module != null && module.isNotEmpty);
    assert(intent != null);
    assert(surfaceRelation != null);

    Completer<ModuleControllerClient> completer =
        new Completer<ModuleControllerClient>();

    // TODO(): map results and reuse for subsequent calls, see getLink.
    ModuleControllerClient controller = new ModuleControllerClient();

    // ignore: unawaited_futures
    proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    // ignore: unawaited_futures
    controller.proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    void handleIntentStatus(fidl.StartModuleStatus status) {
      switch (status) {
        case fidl.StartModuleStatus.success:
          completer.complete(controller);
          break;
        case fidl.StartModuleStatus.noModulesFound:
          completer.completeError(new ResolutionException('no modules found'));
          break;
        default:
          completer.completeError(
              new ResolutionException('unknown status: $status'));
      }
    }

    try {
      proxy.addModuleToStory(
        module,
        intent,
        controller.proxy.ctrl.request(),
        surfaceRelation,
        handleIntentStatus,
      );
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }

    return completer.future;
  }

  /// See [fidl.ModuleContext#embedModule].
  Future<EmbeddedModule> embedModule({
    @required String name,
    @required Intent intent,
  }) {
    assert(name != null && name.isNotEmpty);
    assert(intent != null);

    Completer<EmbeddedModule> completer = new Completer<EmbeddedModule>();
    InterfacePair<ViewOwner> viewOwner = new InterfacePair<ViewOwner>();
    ModuleControllerClient controller = new ModuleControllerClient();

    void handleIntentStatus(fidl.StartModuleStatus status) {
      log.fine('resolved "$name" with status "$status"');

      switch (status) {
        case fidl.StartModuleStatus.success:
          log.fine('configuring view for "$name"');

          // TODO(MS-1437): viewOwner error handling.
          ChildViewConnection connection =
              ChildViewConnection.fromImportToken(ImportToken(
            value: EventPair(viewOwner.passHandle().passChannel().passHandle()),
          ));

          EmbeddedModule result = new EmbeddedModule(
            controller: controller,
            connection: connection,
            view: new ChildView(connection: connection),
          );
          completer.complete(result);
          break;
        case fidl.StartModuleStatus.noModulesFound:
          completer.completeError(new ResolutionException('no modules found'));
          break;
        default:
          completer.completeError(
              new ResolutionException('unknown status: $status'));
      }
    }

    // ignore: unawaited_futures
    proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    // ignore: unawaited_futures
    controller.proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    try {
      proxy.embedModule(
        name,
        intent,
        controller.proxy.ctrl.request(),
        viewOwner.passRequest(),
        handleIntentStatus,
      );
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }

    return completer.future;
  }

  /// See [fidl.ModuleContext#getStoryId].
  Future<String> getStoryId() async {
    Completer<String> completer = new Completer<String>();
    try {
      await bound;

      // ignore: unawaited_futures
      proxy.ctrl.error.then((Object error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      });

      proxy.getStoryId(completer.complete);
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }
    return completer.future;
  }

  /// See [fidl:ModuleContext#active].
  Future<Null> active() async {
    Completer<Null> completer = new Completer<Null>();
    try {
      await bound;

      // ignore: unawaited_futures
      proxy.ctrl.error.then((Object error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      });

      proxy.active();
      completer.complete(null);
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }
    return completer.future;
  }

  /// See [fidl:ModuleContext#done]
  Future<void> done() async {
    Completer completer = new Completer();
    try {
      await bound;

      // ignore: unawaited_futures
      proxy.ctrl.error.then((Object error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      });

      proxy.removeSelfFromStory();
      completer.complete();
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }
    return completer.future;
  }

  /// See [fidl:ModuleContext#RequestStoryVisibilityState]
  Future<void> requestStoryVisibilityState(
      fidl.StoryVisibilityState state) async {
    log.fine('requestStoryVisibilityState requesting state $state');
    Completer completer = new Completer();
    try {
      await bound;

      // ignore: unawaited_futures
      proxy.ctrl.error.then((Object error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      });

      proxy.requestStoryVisibilityState(state);
      completer.complete();
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }
    return completer.future;
  }

  /// See [fidl.ModuleContext#StartOngoingActivity].
  Future<OngoingActivityProxy> startOngoingActivity(
      OngoingActivityType type) async {
    await bound;
    Completer<OngoingActivityProxy> completer =
        new Completer<OngoingActivityProxy>();

    try {
      if (!_ongoingActivityProxy.ctrl.isBound) {
        proxy.startOngoingActivity(type, _ongoingActivityProxy.ctrl.request());
      }
      completer.complete(_ongoingActivityProxy);
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }

    return completer.future;
  }

  void _handleConnectionError() {
    log.severe('ModuleContextClient connection error');
  }

  void _handleClose() {
    log.fine('proxy closed, terminating link clients');
  }

  void _handleUnbind() {
    log.fine('proxy unbound');
  }

  /// Closes the underlying proxy connection, should be called as a response to
  /// Lifecycle::terminate (see https://goo.gl/MmZ2dc).
  Future<Null> terminate() async {
    log.fine('terminate called');
    proxy.ctrl.close();
    return Future.wait(
            _links.map((LinkClient link) => link.terminate()).toList())
        .then((_) => null);
  }
}
