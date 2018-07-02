// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fidl_examples_bindings_test/fidl_async.dart';
import 'package:lib.app.dart/app_async.dart';

Duration durationFromSeconds(double seconds) => new Duration(
    microseconds: (seconds * Duration.microsecondsPerSecond).round());

class TestServerImpl extends TestServer {
  bool _receivedOneWayNoArgs = false;

  @override
  Future<Null> oneWayNoArgs() async {
    _receivedOneWayNoArgs = true;
  }

  @override
  Future<bool> receivedOneWayNoArgs() async {
    return _receivedOneWayNoArgs;
  }

  String _oneWayStringArg;

  @override
  Future<Null> oneWayStringArg(String value) async {
    _oneWayStringArg = value;
  }

  @override
  Future<String> receivedOneWayString() async {
    return _oneWayStringArg;
  }

  int _oneWayThreeArgX;
  int _oneWayThreeArgY;
  NoHandleStruct _oneWayThreeArgZ;

  @override
  Future<Null> oneWayThreeArgs(int x, int y, NoHandleStruct z) async {
    _oneWayThreeArgX = x;
    _oneWayThreeArgY = y;
    _oneWayThreeArgZ = z;
  }

  @override
  Future<TestServer$ReceivedOneWayThreeArgs$Response>
      receivedOneWayThreeArgs() async {
    return new TestServer$ReceivedOneWayThreeArgs$Response(
        _oneWayThreeArgX, _oneWayThreeArgY, _oneWayThreeArgZ);
  }

  @override
  Future<Null> twoWayNoArgs() async {}

  @override
  Future<String> twoWayStringArg(String value) async {
    return value;
  }

  @override
  Future<TestServer$TwoWayThreeArgs$Response> twoWayThreeArgs(
      int x, int y, NoHandleStruct z) async {
    return new TestServer$TwoWayThreeArgs$Response(x, y, z);
  }

  final StreamController<Null> _emptyEventController =
      new StreamController.broadcast();
  @override
  Future<Null> sendEmptyEvent() async {
    _emptyEventController.add(null);
  }

  @override
  Stream<Null> get emptyEvent => _emptyEventController.stream;

  final StreamController<String> _stringEventController =
      new StreamController.broadcast();
  @override
  Future<Null> sendStringEvent(String value) async {
    _stringEventController.add(value);
  }

  @override
  Stream<String> get stringEvent => _stringEventController.stream;

  final StreamController<TestServer$ThreeArgEvent$Response>
      _threeArgEventController = new StreamController.broadcast();

  @override
  Future<Null> sendThreeArgEvent(int x, int y, NoHandleStruct z) async {
    _threeArgEventController
        .add(new TestServer$ThreeArgEvent$Response(x, y, z));
  }

  @override
  Stream<TestServer$ThreeArgEvent$Response> get threeArgEvent =>
      _threeArgEventController.stream;

  final StreamController<int> _multipleEventController =
      new StreamController.broadcast();
  @override
  Future<Null> sendMultipleEvents(int count, double intervalSeconds) async {
    if (intervalSeconds == 0.0) {
      _binding.close();
    } else {
      int index = 0;
      new Timer.periodic(durationFromSeconds(intervalSeconds), (timer) {
        index++;
        _multipleEventController.add(index);
        if (index >= count) {
          timer.cancel();
        }
      });
    }
  }

  @override
  Stream<int> get multipleEvent => _multipleEventController.stream;

  @override
  Future<String> replySlowly(String value, double delaySeconds) {
    return new Future.delayed(durationFromSeconds(delaySeconds), () => value);
  }

  @override
  Future<Null> closeConnection(double delaySeconds) async {
    if (delaySeconds == 0.0) {
      _binding.close();
    } else {
      new Timer(durationFromSeconds(delaySeconds), _binding.close);
    }
  }
}

StartupContext _context;
TestServerImpl _server;
TestServerBinding _binding;

void main(List<String> args) {
  _context = new StartupContext.fromStartupInfo();

  _server = new TestServerImpl();
  _binding = new TestServerBinding();

  _context.outgoingServices.addServiceForName<TestServer>(
      (request) => _binding.bind(_server, request), TestServer.$serviceName);
}
