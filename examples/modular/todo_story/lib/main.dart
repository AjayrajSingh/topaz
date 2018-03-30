// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fuchsia/fuchsia.dart';
import 'package:lib.app.dart/app.dart';
import 'package:fuchsia.fidl.component/component.dart';
import 'package:fidl/fidl.dart';
import 'package:fuchsia.fidl.modular/modular.dart';

import 'data.dart';
import 'view.dart';

// ignore_for_file: public_member_api_docs

final ApplicationContext _appContext = new ApplicationContext.fromStartupInfo();

void _log(String msg) {
  print('[Todo Story Example] $msg');
}

/// An implementation of the [Module] interface.
class TodoModule implements Module, Lifecycle {
  final ModuleBinding _moduleBinding = new ModuleBinding();
  final LifecycleBinding _lifecycleBinding = new LifecycleBinding();
  final Completer<LinkProxy> _linkCompleter = new Completer<LinkProxy>();
  LinkConnector linkConnector;

  TodoModule() {
    linkConnector = new LinkConnector(_linkCompleter.future);
  }

  /// Bind an [InterfaceRequest] for a [Module] interface to this object.
  void bindModule(InterfaceRequest<Module> request) {
    _moduleBinding.bind(this, request);
  }

  /// Bind an [InterfaceRequest] for a [Lifecycle] interface to this object.
  void bindLifecycle(InterfaceRequest<Lifecycle> request) {
    _lifecycleBinding.bind(this, request);
  }

  /// Implementation of the Initialize(Story story, Link link) method.
  @override
  void initialize(InterfaceHandle<ModuleContext> moduleContextHandle,
      InterfaceRequest<ServiceProvider> outgoingServices) {
    _log('TodoModule::initialize()');

    LinkProxy link = new LinkProxy();
    new ModuleContextProxy()
      ..ctrl.bind(moduleContextHandle)
      ..getLink(null, link.ctrl.request());
    _linkCompleter.complete(link);
  }

  /// Implementation of the Lifecycle.Terminate() method.
  @override
  void terminate() {
    _log('TodoModule.terminate()');
    _moduleBinding.close();
    _lifecycleBinding.close();
    exit(0);
  }
}

void main() {
  _log('Module started with ApplicationContext: $_appContext');

  final TodoModule module = new TodoModule();

  _appContext.outgoingServices
    ..addServiceForName(
      (InterfaceRequest<Module> request) {
        _log('Received binding request for Module');
        module.bindModule(request);
      },
      Module.serviceName,
    )
    ..addServiceForName(
      module.bindLifecycle,
      Lifecycle.serviceName,
    );

  runApp(new MaterialApp(
    title: 'Todo (Story)',
    home: new TodoListView(module.linkConnector),
    theme: new ThemeData(primarySwatch: Colors.blue),
  ));
}
