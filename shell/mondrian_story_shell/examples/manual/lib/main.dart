// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fuchsia/fuchsia.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.fidl/service_provider.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.lifecycle.fidl/lifecycle.fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.module.fidl/module.fidl.dart';
import 'package:lib.module.fidl/module_context.fidl.dart';
import 'package:lib.module.fidl/module_controller.fidl.dart';
import 'package:lib.module.fidl/module_state.fidl.dart';
import 'package:lib.surface.fidl/surface.fidl.dart';

const String _kModuleUrl = 'example_manual_relationships';
final ApplicationContext _appContext = new ApplicationContext.fromStartupInfo();

/// This is used for keeping the reference around.
ModuleImpl _module = new ModuleImpl();
ModuleContextProxy _moduleContext = new ModuleContextProxy();
List<_ModuleStopperWatcher> _watchers = <_ModuleStopperWatcher>[];
int _childId = 0;

/// The key for the child modules list
final GlobalKey<ChildModulesViewState> kChildModulesKey = new GlobalKey();

class _ModuleStopperWatcher extends ModuleWatcher {
  final ModuleControllerProxy _moduleController;
  final ModuleWatcherBinding _binding = new ModuleWatcherBinding();
  final String name;

  _ModuleStopperWatcher(this._moduleController, this.name) {
    _moduleController.watch(_binding.wrap(this));
  }
  @override
  void onStateChange(ModuleState newState) {
    log.info('Module state changed to $newState');
    if (newState == ModuleState.done) {
      _moduleController.stop(() {
        log.info('Module stopped!');
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
    null, // incomingServices,
    moduleController.ctrl.request(),
    relation,
    true,
  );
  log.info('Started sub-module $name');

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
  const LaunchModuleButton(this._relation, this._display);

  @override
  Widget build(BuildContext context) {
    return new Padding(
      padding: const EdgeInsets.all(16.0),
      child: new RaisedButton(
        child: new Center(
          child: new Text(_display),
        ),
        onPressed: () {
          startModuleInShell(_relation);
        },
      ),
    );
  }
}

/// White box grouping
class Grouping extends StatelessWidget {
  /// The children in this grouping
  final List<Widget> children;

  /// Construct Grouping
  const Grouping({this.children});

  @override
  Widget build(BuildContext context) {
    return new Container(
      color: const Color(0xFFFFFFFF),
      margin: const EdgeInsets.all(10.0),
      padding: const EdgeInsets.all(10.0),
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
  const CopresentLauncher({Key key}) : super(key: key);

  @override
  CopresentLauncherState createState() => new CopresentLauncherState();
}

/// Copresent Launch State
class CopresentLauncherState extends State<CopresentLauncher> {
  double _copresentEmphasisExp = 0.0;

  double get _emphasis =>
      (math.pow(2, _copresentEmphasisExp) * 10.0).roundToDouble() / 10.0;

  @override
  Widget build(BuildContext context) => new Container(
        alignment: FractionalOffset.center,
        constraints: new BoxConstraints(maxWidth: 200.0),
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
                new SurfaceRelation(
                  emphasis: _emphasis,
                  arrangement: SurfaceArrangement.copresent,
                ),
                'Copresent'),
            new LaunchModuleButton(
                new SurfaceRelation(
                  emphasis: _emphasis,
                  arrangement: SurfaceArrangement.copresent,
                  dependency: SurfaceDependency.dependent,
                ),
                'Dependent\nCopresent'),
          ],
        ),
      );
}

/// Display controls for a child module
class ChildController extends StatelessWidget {
  /// Constructor
  const ChildController(this._watcher);

  final _ModuleStopperWatcher _watcher;

  @override
  Widget build(BuildContext context) {
    return new Row(
      children: <Widget>[
        new Text('${_watcher.name} '),
        new Expanded(
          child: new Padding(
            padding: const EdgeInsets.all(2.0),
            child: new ButtonTheme(
              padding: const EdgeInsets.all(1.0),
              child: new RaisedButton(
                child: const Text(
                  'Focus',
                  style: const TextStyle(fontSize: 10.0),
                ),
                onPressed: _watcher.focus,
              ),
            ),
          ),
        ),
        new Expanded(
          child: new Padding(
            padding: const EdgeInsets.all(2.0),
            child: new ButtonTheme(
              padding: const EdgeInsets.all(1.0),
              child: new RaisedButton(
                child: const Text(
                  'Dismiss',
                  style: const TextStyle(fontSize: 10.0),
                ),
                onPressed: _watcher.defocus,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// View for currently live child modules
class ChildModulesView extends StatefulWidget {
  /// ChildModulesView
  const ChildModulesView({Key key}) : super(key: key);

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
        height: 60.0,
        constraints: new BoxConstraints(maxWidth: 200.0),
        child: new Scrollbar(
          child: new ListView.builder(
            itemCount: _watchers.length,
            itemBuilder: (BuildContext context, int index) {
              return new ChildController(_watchers[index]);
            },
          ),
        ),
      );
}

/// Main UI Widget
class MainWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    DateTime now = new DateTime.now().toLocal();
    return new Scaffold(
      body: new Center(
        child: new Container(
          constraints: new BoxConstraints(maxWidth: 200.0),
          child: new Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              new Grouping(
                children: <Widget>[
                  new Text(
                      "Module ${now.minute}:${now.second.toString().padLeft(2, '0')}"),
                  new Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: new RaisedButton(
                      child: const Text('Close'),
                      onPressed: () {
                        log.info('Module done...');
                        _moduleContext.done();
                      },
                    ),
                  ),
                ],
              ),
              new Grouping(
                children: <Widget>[
                  const CopresentLauncher(),
                  const Divider(),
                  new LaunchModuleButton(
                      new SurfaceRelation(
                          arrangement: SurfaceArrangement.sequential),
                      'Sequential'),
                ],
              ),
              new Grouping(
                children: <Widget>[
                  const Text('Children'),
                  new ChildModulesView(key: kChildModulesKey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Module Service
class ModuleImpl implements Module, Lifecycle {
  final ModuleBinding _moduleBinding = new ModuleBinding();
  final LifecycleBinding _lifecycleBinding = new LifecycleBinding();

  /// Bind an [InterfaceRequest] for a [Module] to this
  void bindModule(InterfaceRequest<Module> request) {
    _moduleBinding.bind(this, request);
  }

  /// Bind an [InterfaceRequest] for a [Lifecycle] interface to this object.
  void bindLifecycle(InterfaceRequest<Lifecycle> request) {
    _lifecycleBinding.bind(this, request);
  }

  @override
  void initialize(InterfaceHandle<ModuleContext> moduleContextHandle,
      InterfaceRequest<ServiceProvider> outgoingServices) {
    log.info('ModuleImpl::initialize call');

    _moduleContext.ctrl.bind(moduleContextHandle);
  }

  @override
  void terminate() {
    log.info('ModuleImpl::terminate call');
    _moduleContext.ctrl.close();
    _moduleBinding.close();
    _lifecycleBinding.close();
    exit(0);
  }
}

/// Entry point for this module.
void main() {
  setupLogger(name: 'exampleManualRelationships');

  /// Add [ModuleImpl] to this application's outgoing ServiceProvider.
  _appContext.outgoingServices
    ..addServiceForName(
      (InterfaceRequest<Module> request) {
        log.info('Received binding request for Module');
        _module.bindModule(request);
      },
      Module.serviceName,
    )
    ..addServiceForName(
      (InterfaceRequest<Lifecycle> request) {
        _module.bindLifecycle(request);
      },
      Lifecycle.serviceName,
    );

  Color randomColor =
      new Color(0xFF000000 + new math.Random().nextInt(0xFFFFFF));

  runApp(new MaterialApp(
    title: 'Manual Module',
    home: new MainWidget(),
    theme: new ThemeData(canvasColor: randomColor),
  ));
}
