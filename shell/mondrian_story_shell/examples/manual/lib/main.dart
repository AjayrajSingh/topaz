// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:application.lib.app.dart/app.dart';
import 'package:application.services/service_provider.fidl.dart';
import 'package:apps.modular.services.module/module.fidl.dart';
import 'package:apps.modular.services.module/module_context.fidl.dart';
import 'package:apps.modular.services.module/module_controller.fidl.dart';
import 'package:apps.modular.services.module/module_state.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.fidl.dart/bindings.dart';

const String _kModuleUrl = 'file:///system/apps/example_manual_relationships';
final ApplicationContext _appContext = new ApplicationContext.fromStartupInfo();

/// This is used for keeping the reference around.
ModuleImpl _module;
ModuleContextProxy _moduleContext = new ModuleContextProxy();
LinkProxy _link = new LinkProxy();
List<ModuleWatcher> _watchers = <ModuleWatcher>[];

void _log(String msg) {
  print('[Manual Relationships Module] $msg');
}

class _ModuleStopperWatcher extends ModuleWatcher {
  final ModuleControllerProxy _moduleController;
  final ModuleWatcherBinding _binding = new ModuleWatcherBinding();

  _ModuleStopperWatcher(this._moduleController) {
    _moduleController.watch(_binding.wrap(this));
  }
  @override
  void onStateChange(ModuleState newState) {
    _log('Module state changed to $newState');
    if (newState == ModuleState.done) {
      _moduleController.stop(() {
        _log('Module stopped!');
        _binding.unbind();
        _watchers.remove(this);
      });
    }
  }
}

/// Starts a new module
void startModuleInShell(String viewType) {
  ModuleControllerProxy moduleController = new ModuleControllerProxy();

  _moduleContext.startModuleInShell(
    '',
    _kModuleUrl,
    duplicateLink(),
    null, // outgoingServices,
    null, // incomingServices,
    moduleController.ctrl.request(),
    viewType,
  );
  _log('Started sub-module');

  _watchers.add(new _ModuleStopperWatcher(moduleController));
}

/// Obtains a duplicated [InterfaceHandle] for the current [Link] object.
InterfaceHandle<Link> duplicateLink() {
  InterfacePair<Link> linkPair = new InterfacePair<Link>();
  _link.dup(linkPair.passRequest());
  return linkPair.passHandle();
}

/// Button widget to start module
class LaunchModuleButton extends StatelessWidget {
  /// The  relationship to introduce a new surface with
  final String _relationship;

  /// The display text for the relationship
  final String _display;

  /// Construct a button [Widget] to add new surface with given relationship
  LaunchModuleButton(this._relationship, this._display);

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

/// Container Widget with Title
class TitleText extends StatelessWidget {
  final String _title;

  /// Construct TitleText
  TitleText(this._title);

  @override
  Widget build(BuildContext context) {
    return new Container(
        color: new Color(0xFFFFFFFF),
        child: new Padding(
          padding: const EdgeInsets.all(32.0),
          child: new Text(_title),
        ));
  }
}

/// Main UI Widget
class MainWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    DateTime now = new DateTime.now().toLocal();
    return new Scaffold(
      body: new Center(
          child: new Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          new TitleText(
              "Module ${now.minute}:${now.second.toString().padLeft(2, '0')}"),
          new LaunchModuleButton('', 'Serial'),
          new LaunchModuleButton('h', 'Hierarchical'),
          new Padding(
            padding: const EdgeInsets.all(16.0),
            child: new RaisedButton(
              child: new Text('Close'),
              onPressed: () {
                _log('Module done...');
                _moduleContext.done();
              },
            ),
          ),
        ],
      )),
    );
  }
}

/// Module Service
class ModuleImpl extends Module {
  final ModuleBinding _binding = new ModuleBinding();

  /// Bind an [InterfaceRequest] for a [Module] to this
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
    (InterfaceRequest<Module> request) {
      _log('Received binding request for Module');
      _module = new ModuleImpl()..bind(request);
    },
    Module.serviceName,
  );

  Color randomColor = new Color(0xFF000000 + new Random().nextInt(0xFFFFFF));

  runApp(new MaterialApp(
    title: 'Manual Module',
    home: new MainWidget(),
    theme: new ThemeData(canvasColor: randomColor),
  ));
}
