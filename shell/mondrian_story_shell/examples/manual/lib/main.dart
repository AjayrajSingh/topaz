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
import 'package:apps.modular.services.surface/surface.fidl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.fidl.dart/bindings.dart';

const String _kModuleUrl = 'file:///system/apps/example_manual_relationships';
final ApplicationContext _appContext = new ApplicationContext.fromStartupInfo();

/// This is used for keeping the reference around.
ModuleImpl _module;
ModuleContextProxy _moduleContext = new ModuleContextProxy();
List<_ModuleStopperWatcher> _watchers = <_ModuleStopperWatcher>[];
int _childId = 0;

/// The key for the child modules list
final GlobalKey<ChildModulesViewState> kChildModulesKey = new GlobalKey();

void _log(String msg) {
  print('[Manual Relationships Module] $msg');
}

class _ModuleStopperWatcher extends ModuleWatcher {
  final ModuleControllerProxy _moduleController;
  final ModuleWatcherBinding _binding = new ModuleWatcherBinding();
  final String name;

  _ModuleStopperWatcher(this._moduleController, this.name) {
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
        kChildModulesKey.currentState.refresh();
      });
    }
  }

  void focus() {
    _moduleController.focus();
  }

  void defocus() {
    _moduleController.defocus();
  }
}

/// Starts a new module
void startModuleInShell(SurfaceRelation relation) {
  ModuleControllerProxy moduleController = new ModuleControllerProxy();

  _childId++;
  String name = 'C$_childId';

  _moduleContext.startModuleInShell(
    name,
    _kModuleUrl,
    null, // link
    null, // outgoingServices,
    null, // incomingServices,
    moduleController.ctrl.request(),
    relation,
    true,
  );
  _log('Started sub-module $name');

  _watchers.add(new _ModuleStopperWatcher(moduleController, name));
  kChildModulesKey.currentState.refresh();
}

/// Button widget to start module
class LaunchModuleButton extends StatelessWidget {
  /// The  relationship to introduce a new surface with
  final SurfaceRelation _relation;

  /// The display text for the relationship
  final String _display;

  /// Construct a button [Widget] to add new surface with given relationship
  LaunchModuleButton(this._relation, this._display);

  @override
  Widget build(BuildContext context) {
    return new Padding(
        padding: const EdgeInsets.all(16.0),
        child: new RaisedButton(
          child: new Text(_display),
          onPressed: () {
            startModuleInShell(_relation);
          },
        ));
  }
}

/// White box grouping
class Grouping extends StatelessWidget {
  /// The children in this grouping
  final List<Widget> children;

  /// Construct Grouping
  Grouping({this.children});

  @override
  Widget build(BuildContext context) {
    return new Container(
      color: new Color(0xFFFFFFFF),
      margin: const EdgeInsets.all(10.0),
      padding: const EdgeInsets.all(20.0),
      child: new Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
  }
}

/// Specify an emphasis and launch a copresented surface
class CopresentLauncher extends StatefulWidget {
  /// CopresentLauncher
  CopresentLauncher({Key key}) : super(key: key);

  @override
  CopresentLauncherState createState() => new CopresentLauncherState();
}

/// Copresent Launch State
class CopresentLauncherState extends State<CopresentLauncher> {
  double _copresentEmphasisExp = 0.0;

  double get _emphasis =>
      (pow(2, _copresentEmphasisExp) * 10.0).roundToDouble() / 10.0;

  @override
  Widget build(BuildContext context) => new Container(
        alignment: FractionalOffset.center,
        constraints: new BoxConstraints(maxWidth: 200.0),
        padding: new EdgeInsets.only(bottom: 20.0),
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            new Slider(
              min: -1.6,
              max: 1.6,
              value: _copresentEmphasisExp,
              label: 'Emphasis: $_emphasis',
              onChanged: (double value) =>
                  setState(() => _copresentEmphasisExp = value),
            ),
            new LaunchModuleButton(
                new SurfaceRelation()
                  ..emphasis = _emphasis
                  ..arrangement = SurfaceArrangement.copresent,
                'Copresent'),
          ],
        ),
      );
}

/// Display controls for a child module
class ChildController extends StatelessWidget {
  /// Constructor
  ChildController(this._watcher);

  final _ModuleStopperWatcher _watcher;

  @override
  Widget build(BuildContext context) => new Row(
        children: <Widget>[
          new Text('${_watcher.name}'),
          new RaisedButton(
            child: new Text('Focus'),
            onPressed: () => _watcher.focus(),
          ),
          new RaisedButton(
            child: new Text('Dismiss'),
            onPressed: () => _watcher.defocus(),
          ),
        ],
      );
}

/// View for currently live child modules
class ChildModulesView extends StatefulWidget {
  /// ChildModulesView
  ChildModulesView({Key key}) : super(key: key);

  @override
  ChildModulesViewState createState() => new ChildModulesViewState();
}

/// Copresent Launch State
class ChildModulesViewState extends State<ChildModulesView> {
  /// Reload the child list
  void refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => new Container(
      alignment: FractionalOffset.center,
      constraints: new BoxConstraints(maxWidth: 200.0),
      child: new Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _watchers.isEmpty
              ? <Widget>[new Text('NONE')]
              : _watchers
                  .map((_ModuleStopperWatcher w) => new ChildController(w))
                  .toList()));
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
          new Grouping(
            children: <Widget>[
              new Text(
                  "Module ${now.minute}:${now.second.toString().padLeft(2, '0')}"),
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
          ),
          new Grouping(
            children: <Widget>[
              new CopresentLauncher(),
              new LaunchModuleButton(
                  new SurfaceRelation()
                    ..arrangement = SurfaceArrangement.sequential,
                  'Sequential'),
            ],
          ),
          new Grouping(
            children: <Widget>[
              new Text('Children'),
              new ChildModulesView(key: kChildModulesKey),
            ],
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
      InterfaceHandle<ServiceProvider> incomingServices,
      InterfaceRequest<ServiceProvider> outgoingServices) {
    _log('ModuleImpl::initialize call');

    _moduleContext.ctrl.bind(moduleContextHandle);
  }

  @override
  void stop(void done()) {
    _log('ModuleImpl::stop call');

    _moduleContext.ctrl.close();

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
