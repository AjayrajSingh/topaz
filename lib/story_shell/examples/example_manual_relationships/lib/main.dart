// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fidl/fidl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:fuchsia/fuchsia.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.module_resolver.dart/intent_builder.dart';

import 'grouping.dart';
import 'launch_copresent_button.dart';
import 'start_module_button.dart';

final StartupContext _context = new StartupContext.fromStartupInfo();

/// This is used for keeping the reference around.
ModuleImpl _module = new ModuleImpl();
ModuleContextProxy _moduleContext = new ModuleContextProxy();
int _childId = 0;

String _generateChildId() {
  _childId++;
  return 'C$_childId';
}

String _fixedChildId() {
  return 'ontop_child';
}

class _ModuleControllerWrapper {
  final ModuleControllerProxy proxy;
  final String name;

  _ModuleControllerWrapper(this.proxy, this.name);

  void focus() {
    proxy.focus();
  }

  void defocus() {
    proxy.defocus();
  }
}

/// Starts a predefined test container
void startContainerInShell() {
  IntentBuilder intentBuilder = new IntentBuilder.handler(
      'fuchsia-pkg://fuchsia.com/example_manual_relationships#meta/example_manual_relationships.cmx');

  const List<double> leftRect = const <double>[0.0, 0.0, 0.5, 1.0];
  const List<double> trRect = const <double>[0.5, 0.0, 0.5, 0.5];
  const List<double> brRect = const <double>[0.5, 0.5, 0.5, 0.5];
  LayoutEntry left = new LayoutEntry(
      nodeName: 'left', rectangle: new Float32List.fromList(leftRect));
  LayoutEntry tr = new LayoutEntry(
      nodeName: 'top_right', rectangle: new Float32List.fromList(trRect));
  LayoutEntry br = new LayoutEntry(
      nodeName: 'bottom_right', rectangle: new Float32List.fromList(brRect));
  ContainerLayout main =
      new ContainerLayout(surfaces: <LayoutEntry>[left, tr, br]);
  List<ContainerLayout> layouts = <ContainerLayout>[main];
  ContainerRelationEntry rootLeft = const ContainerRelationEntry(
      nodeName: 'left',
      parentNodeName: 'test',
      relationship: const SurfaceRelation());
  ContainerRelationEntry rootTr = const ContainerRelationEntry(
      nodeName: 'top_right',
      parentNodeName: 'test',
      relationship: const SurfaceRelation());
  ContainerRelationEntry rootBr = const ContainerRelationEntry(
      nodeName: 'bottom_right',
      parentNodeName: 'test',
      relationship:
          const SurfaceRelation(dependency: SurfaceDependency.dependent));
  List<ContainerRelationEntry> relations = <ContainerRelationEntry>[
    rootLeft,
    rootTr,
    rootBr
  ];
  ContainerNode leftNode =
      new ContainerNode(nodeName: 'left', intent: intentBuilder.intent);
  ContainerNode trNode =
      new ContainerNode(nodeName: 'top_right', intent: intentBuilder.intent);
  ContainerNode brNode =
      new ContainerNode(nodeName: 'bottom_right', intent: intentBuilder.intent);
  List<ContainerNode> nodes = <ContainerNode>[leftNode, trNode, brNode];

  _moduleContext.startContainerInShell(
      'test',
      const SurfaceRelation(
          arrangement: SurfaceArrangement.sequential,
          dependency: SurfaceDependency.none),
      layouts,
      relations,
      nodes);
}

/// Launch a (prebaked) Container
class LaunchContainerButton extends StatelessWidget {
  /// Construct a button [Widget] to add a predefined container to the story
  const LaunchContainerButton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: const EdgeInsets.all(16.0),
      child: const RaisedButton(
        child: const Center(
          child: const Text('Launch Container'),
        ),
        onPressed: (startContainerInShell),
      ),
    );
  }
}

/// Display controls for a child module
class ChildController extends StatelessWidget {
  /// Constructor
  const ChildController(this._controller);

  final _ModuleControllerWrapper _controller;

  @override
  Widget build(BuildContext context) {
    return new Row(
      children: <Widget>[
        new Text('${_controller.name} '),
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
                onPressed: _controller.focus,
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
                onPressed: _controller.defocus,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Main UI Widget
class MainWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    DateTime now = new DateTime.now().toLocal();
    return new Scaffold(
      body: new Center(
        child: new Container(
          constraints: const BoxConstraints(maxWidth: 200.0),
          child: new ListView(
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
                        // NOTE(mesch): There used to be code here that calls
                        // ModuleContext.Done(), but that method no longer
                        // exists.
                        log.warning('Module done is no longer supported.');
                      },
                    ),
                  ),
                ],
              ),
              new Grouping(
                children: <Widget>[
                  CopresentLauncher(_moduleContext, _generateChildId),
                  const Divider(),
                  StartModuleButton(
                    _moduleContext,
                    const SurfaceRelation(
                        arrangement: SurfaceArrangement.sequential),
                    'Sequential',
                    _generateChildId,
                  ),
                  StartModuleButton(
                    _moduleContext,
                    const SurfaceRelation(
                        arrangement: SurfaceArrangement.ontop),
                    'On Top',
                    _fixedChildId,
                  ),
                  const LaunchContainerButton(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Module related Services: Lifecycle and ModuleContext
class ModuleImpl implements Lifecycle {
  final LifecycleBinding _lifecycleBinding = new LifecycleBinding();

  ModuleImpl() {
    log.info('ModuleImpl::initialize call');
    connectToService(_context.environmentServices, _moduleContext.ctrl);
  }

  /// Bind an [InterfaceRequest] for a [Lifecycle] interface to this object.
  void bindLifecycle(InterfaceRequest<Lifecycle> request) {
    _lifecycleBinding.bind(this, request);
  }

  @override
  void terminate() {
    log.info('ModuleImpl::terminate call');
    _moduleContext.ctrl.close();
    _lifecycleBinding.close();
    exit(0);
  }
}

/// Entry point for this module.
void main() {
  setupLogger(name: 'exampleManualRelationships');

  /// Add [ModuleImpl] to this application's outgoing ServiceProvider.
  _context.outgoingServices.addServiceForName(
    (InterfaceRequest<Lifecycle> request) {
      _module.bindLifecycle(request);
    },
    Lifecycle.$serviceName,
  );

  Color randomColor =
      new Color(0xFF000000 + new math.Random().nextInt(0xFFFFFF));

  runApp(new MaterialApp(
    title: 'Manual Module',
    home: new MainWidget(),
    theme: new ThemeData(canvasColor: randomColor),
  ));
}
