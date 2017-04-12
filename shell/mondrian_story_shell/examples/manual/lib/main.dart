// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:application.services/service_provider.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:apps.modular.services.module/module.fidl.dart';
import 'package:apps.modular.services.module/module_context.fidl.dart';
import 'package:apps.modular.services.module/module_controller.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

const String _kModuleUrl = 'file:///system/apps/example_manual_relationships';
final ApplicationContext _appContext = new ApplicationContext.fromStartupInfo();

/// This is used for keeping the reference around.
ModuleImpl _module;
ModuleContextProxy _moduleContext = new ModuleContextProxy();
LinkProxy _link = new LinkProxy();

void _log(String msg) {
  print('[Manual Relationships Module] $msg');
}

/// Starts a new module
void startModuleInShell(String viewType) {
  InterfacePair<ModuleController> moduleControllerPair =
      new InterfacePair<ModuleController>();

  _moduleContext.startModuleInShell(
    '',
    _kModuleUrl,
    duplicateLink(),
    null, // outgoingServices,
    null, // incomingServices,
    moduleControllerPair.passRequest(),
    viewType,
  );
  _log('Started sub-module');
}

/// Obtains a duplicated [InterfaceHandle] for the current [Link] object.
InterfaceHandle<Link> duplicateLink() {
  InterfacePair<Link> linkPair = new InterfacePair<Link>();
  _link.dup(linkPair.passRequest());
  return linkPair.passHandle();
}

/// Button widget to start module
class LaunchModuleButton extends StatelessWidget {
  final String _relationship;
  final String _display;

  LaunchModuleButton(this._relationship, this._display) {}

  @override
  Widget build(BuildContext context) {
    return new Padding(
        padding: const EdgeInsets.all(16.0),
        child: new RaisedButton(
          child: new Text(_display),
          onPressed: () {
            startModuleInShell(_relationship);
          },
        ));
  }
}

/// Main UI Widget
class MainWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      body: new Center(
          child: new Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          new LaunchModuleButton('s', 'Serial'),
          new LaunchModuleButton('h', 'Hierarchical'),
          new LaunchModuleButton('d', 'Dependent')
        ],
      )),
    );
  }
}

/// Module Service
class ModuleImpl extends Module {
  final ModuleBinding _binding = new ModuleBinding();

  void bind(InterfaceRequest<Module> request) {
    _binding.bind(this, request);
  }

  @override
  void initialize(
      InterfaceHandle<ModuleContext> moduleContextHandle,
      InterfaceHandle<Link> linkHandle,
      InterfaceHandle<ServiceProvider> incomingServices,
      InterfaceRequest<ServiceProvider> outgoingServices) {
    _log('ModuleImpl::initialize call');

    _moduleContext.ctrl.bind(moduleContextHandle);
    _link.ctrl.bind(linkHandle);
  }

  @override
  void stop(void done()) {
    _log('ModuleImpl::stop call');

    _moduleContext.ctrl.close();
    _link.ctrl.close();

    done();
  }
}

/// Entry point for this module.
void main() {
  /// Add [ModuleImpl] to this application's outgoing ServiceProvider.
  _appContext.outgoingServices.addServiceForName(
    (request) {
      _log('Received binding request for Module');
      _module = new ModuleImpl()..bind(request);
    },
    Module.serviceName,
  );

  runApp(new MaterialApp(
    title: 'Manual Module',
    home: new MainWidget(),
  ));
}
