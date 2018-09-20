// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_as

import 'dart:async';

import 'package:lib.schemas.dart/entity_codec.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.module.dart/module.dart';
import 'package:fidl_fuchsia_modular/fidl.dart'
    show SurfaceRelation, SurfaceArrangement, SurfaceDependency;
import 'package:flutter/material.dart';

class LinkStreamController {
  final StreamController<String> controller;
  final bool watchAll;

  LinkStreamController({@required this.controller, @required this.watchAll});
}

class FakeModuleDriver implements ModuleDriver {
  final _linkValue = {};
  final _linkStreamControllers = {};
  final _startModuleIntents = [];
  final _fakeModuleContext = FakeModuleContext();
  final _fakeModuleControllerClient = FakeModuleControllerClient();

  @override
  // ignore: use_to_and_as_if_applicable
  Future<ModuleDriver> start() {
    return Future.value(this);
  }

  // Value is only send to watchers registered with all = true.
  @override
  Future<String> put<T>(String key, T value, EntityCodec<T> codec) async {
    _linkValue[key] = codec.encode(value);
    List<LinkStreamController> streamContollerList =
        _getLinkStreamControllerList(key);
    for (var linkStreamController in streamContollerList) {
      if (linkStreamController.watchAll) {
        /// Encode and decode to tests codec.
        linkStreamController.controller.add(codec.encode(value));
      }
    }
    return null;
  }

  @override
  ModuleContextClient get moduleContext => _fakeModuleContext;

  @override
  Stream<T> watch<T>(String key, EntityCodec<T> codec, {bool all = false}) {
    // Do not combine the next two lines or dart gets confused about types.
    // ignore: close_sinks
    StreamController streamController = _createNewStreamController(key, all);
    return streamController.stream.map(codec.decode);
  }

  @override
  Future<ModuleControllerClient> startModule(
      {@required Intent intent,
      String name,
      String module,
      SurfaceRelation surfaceRelation = const SurfaceRelation(
        arrangement: SurfaceArrangement.copresent,
        dependency: SurfaceDependency.dependent,
        emphasis: 0.5,
      )}) {
    _startModuleIntents.add(intent);
    return Future.value(_fakeModuleControllerClient);
  }

  /// Puts a value on a link from a test. Value is sent to all watcher of the
  /// link.
  void putTestValue<T>(String key, T value, EntityCodec<T> codec) {
    _linkValue[key] = codec.encode(value);
    List<LinkStreamController> streamContollerList =
        _getLinkStreamControllerList(key);
    for (var linkStreamController in streamContollerList) {
      linkStreamController.controller.add(codec.encode(value));
    }
  }

  /// Returns the most recent value put on a link or null if no value has been
  /// put on the link.
  T getTestLinkCurrentValue<T>(String key, EntityCodec<T> codec) {
    return codec.decode(_linkValue[key]);
  }

  /// Returns a list of intents that have been sent to [startModule].
  List<Intent> getTestStartModuleIntents() {
    return List.unmodifiable(_startModuleIntents);
  }

  void cleanUp() {
    _linkStreamControllers.forEach((_, controllerList) =>
        // ignore: avoid_function_literals_in_foreach_calls
        controllerList.forEach((contoller) => contoller.controller.close()));
  }

  StreamController<String> _createNewStreamController<T>(
      String key, bool watchAll) {
    // Do not combine the lines in this method or dart gets confused about
    // types.
    StreamController<String> newController = StreamController();
    LinkStreamController newLinkController =
        LinkStreamController(controller: newController, watchAll: watchAll);
    List<LinkStreamController> linkStreamControllerList =
        _getLinkStreamControllerList(key);
    // ignore: cascade_invocations
    linkStreamControllerList.add(newLinkController);
    return newController;
  }

  List<LinkStreamController> _getLinkStreamControllerList(String key) {
    // Do not combine the lines in this method or dart gets confused about
    // types.
    if (!_linkStreamControllers.containsKey(key)) {
      // ignore: close_sinks
      List<LinkStreamController> controllerList = [];
      _linkStreamControllers.putIfAbsent(key, () => controllerList);
    }

    return _linkStreamControllers[key];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    log.warning(
        'Method ${invocation.memberName} not implemented in FakeModuleDriver');
  }
}

class FakeModuleContext implements ModuleContextClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    log.warning(
        'Method ${invocation.memberName} not implemented in FakeModuleContext');
  }
}

class FakeModuleControllerClient implements ModuleControllerClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    log.warning(
        'Method ${invocation.memberName} not implemented in FakeModuleControllerClient');
  }
}
