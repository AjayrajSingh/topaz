// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fidl_fuchsia_modular/fidl_async.dart';
import 'package:fuchsia_logger/logger.dart';
import 'package:fuchsia_modular/module.dart' as mod;

import 'grouping.dart';
import 'launch_copresent_button.dart';
import 'start_module_button.dart';

/// This is used for keeping the reference around.
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
  log.info('startContainerInShell is no longer supported.');
}

/// Launch a (prebaked) Container
class LaunchContainerButton extends StatelessWidget {
  /// Construct a button [Widget] to add a predefined container to the story
  const LaunchContainerButton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: RaisedButton(
        child: Center(
          child: Text('Launch Container'),
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
    return Row(
      children: <Widget>[
        Text('${_controller.name} '),
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(2.0),
            child: ButtonTheme(
              padding: EdgeInsets.all(1.0),
              child: RaisedButton(
                child: Text(
                  'Focus',
                  style: TextStyle(fontSize: 10.0),
                ),
                onPressed: _controller.focus,
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(2.0),
            child: ButtonTheme(
              padding: EdgeInsets.all(1.0),
              child: RaisedButton(
                child: Text(
                  'Dismiss',
                  style: TextStyle(fontSize: 10.0),
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
    DateTime now = DateTime.now().toLocal();
    return Scaffold(
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 200.0),
          child: ListView(
            children: <Widget>[
              Grouping(
                children: <Widget>[
                  Text(
                      "Module ${now.minute}:${now.second.toString().padLeft(2, '0')}"),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: RaisedButton(
                      child: Text('Close'),
                      onPressed: mod.Module().removeSelfFromStory,
                    ),
                  ),
                ],
              ),
              Grouping(
                children: <Widget>[
                  CopresentLauncher(_generateChildId),
                  const Divider(),
                  StartModuleButton(
                    const SurfaceRelation(
                        arrangement: SurfaceArrangement.sequential),
                    'Sequential',
                    _generateChildId,
                  ),
                  StartModuleButton(
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

/// Entry point for this module.
void main() {
  setupLogger(name: 'exampleManualRelationships');

  // Opt out of intent handling for this module
  mod.Module().registerIntentHandler(mod.NoopIntentHandler());

  Color randomColor = Color(0xFF000000 + math.Random().nextInt(0xFFFFFF));

  runApp(MaterialApp(
    title: 'Manual Module',
    home: MainWidget(),
    theme: ThemeData(canvasColor: randomColor),
  ));
}
