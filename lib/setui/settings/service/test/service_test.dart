import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_setui/fidl.dart';
import 'package:flutter/material.dart';
import 'package:lib_setui_settings_common/setting_source.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../lib/service.dart';
import '../lib/src/local_service.dart';
import '../lib/src/setting_controller.dart';
// ignore_for_file: avoid_relative_lib_imports

const String defaultValue = 'default';

const String value1 = 'value1';

void main() {
  SetUiServiceAdapter manager;
  LocalSetUiService service;
  FakeSettingControllerCreator fakeControllers;

  setUp(() {
    fakeControllers = FakeSettingControllerCreator();
    service = LocalSetUiService(
        creator: fakeControllers, proxyBinder: _bindListenerProxy);
    manager = SetUiServiceAdapter.withService(service, _bindListener);
  });

  group('SetUi service', () {
    test('gets an object that then gets updated', () async {
      final object = manager.fetch<String>(SettingType.unknown);
      expect(object.state, defaultValue);

      final controller = fakeControllers.fakes[SettingType.unknown];
      controller.item.value = value1;
      expect(object.state, value1);
    });

    test('sets a value', () async {
      final object = manager.fetch<String>(SettingType.unknown);
      expect(object.state, defaultValue);

      final response = await manager.update(stringObject(value1));
      expect(response.returnCode, ReturnCode.ok);
      expect(object.state, value1);
    });
    test('sets a value without listeners and closes after set', () async {
      final response = await manager.update(stringObject(value1));
      expect(response.returnCode, ReturnCode.ok);
      final FakeStringSettingController controller =
          fakeControllers.fakes[SettingType.unknown];
      expect(controller.open, false);
    });
    test('calls initialize and close depending on listeners', () async {
      manager.fetch<String>(SettingType.unknown);
      final FakeStringSettingController controller =
          fakeControllers.fakes[SettingType.unknown];

      expect(controller.open, true);

      final FakeSetUiListenerProxy proxy = controller.listeners.single;
      when(proxy.ctrl.isBound).thenReturn(false);
      controller.item.value = value1;

      expect(controller.open, false);

      manager.fetch<String>(SettingType.unknown);

      expect(controller.open, true);
    });
  });
}

Future<void> listenForNextChange(SettingSource notifier) async {
  final completer = Completer();
  notifier.addListener(completer.complete);
  await completer.future;
}

class FakeSettingControllerCreator implements SettingControllerCreator {
  Map<SettingType, FakeStringSettingController> fakes = {};

  @override
  SettingController createController(SettingType type) =>
      fakes.putIfAbsent(type, () => FakeStringSettingController());
}

class FakeStringSettingController extends SettingController {
  final ValueNotifier<String> item = ValueNotifier<String>(defaultValue);
  bool open = false;

  @override
  Future<void> close() async {
    item.removeListener(notifyListeners);
    open = false;
  }

  @override
  Future<void> initialize() async {
    item.addListener(notifyListeners);
    open = true;
  }

  @override
  Future<bool> setSettingValue(SettingsObject value) async {
    item.value = value.data.stringValue;
    return true;
  }

  @override
  SettingsObject get value => stringObject(item.value);
}

InterfaceHandle<SettingListener> _bindListener(SettingListener impl) =>
    MockInterfaceHandle(impl);

SettingListenerProxy _bindListenerProxy(
    InterfaceHandle<SettingListener> listener) {
  final MockInterfaceHandle<SettingListener> handle = listener;
  return FakeSetUiListenerProxy(handle.impl);
}

class MockProxyController<T> extends Mock implements ProxyController<T> {}

class MockInterfaceHandle<T> extends Mock implements InterfaceHandle<T> {
  final T impl;

  MockInterfaceHandle(this.impl);
}

class FakeSetUiListenerProxy implements SettingListenerProxy {
  final SettingListener impl;

  @override
  final MockProxyController<SettingListener> ctrl =
      MockProxyController<SettingListener>();

  FakeSetUiListenerProxy(this.impl) {
    when(ctrl.isBound).thenReturn(true);
  }

  @override
  void notify(SettingsObject object) => impl.notify(object);
}

SettingsObject stringObject(String value) => SettingsObject(
    settingType: SettingType.unknown, data: SettingData.withStringValue(value));
