import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_setui/fidl.dart';
import 'package:flutter/material.dart';
import 'package:lib_setui_service/service.dart';
import 'package:lib_setui_service/src/local_service.dart';
import 'package:lib_setui_service/src/setting_controller.dart';
import 'package:lib_setui_settings_common/setting_source.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
// ignore_for_file: implementation_imports

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
    manager = SetUiServiceAdapter.withService(service, _bindListener, null);
  });

  group('SetUi service', () {
    test('gets an object that then gets updated', () async {
      final SettingSource<String> object =
          manager.fetch<String>(SettingType.unknown);

      await awaitForSetting(object, defaultValue);
      expect(object.state, defaultValue);

      final controller = fakeControllers.fakes[SettingType.unknown];
      controller.item.value = value1;

      await awaitForSetting(object, value1);
      expect(object.state, value1);
    });

    test('sets a value', () async {
      final object = manager.fetch<String>(SettingType.unknown);

      await awaitForSetting(object, defaultValue);
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
    test('mutates a value', () async {
      final object = manager.fetch<String>(SettingType.unknown);

      await awaitForSetting(object, defaultValue);
      expect(object.state, defaultValue);

      final response = await manager.mutate(
          SettingType.unknown,
          Mutation.withStringMutationValue(StringMutation(
              operation: StringOperation.update, value: value1)));
      expect(response.returnCode, ReturnCode.ok);

      expect(object.state, value1);
    });
    test('calls initialize and close depending on listeners', () async {
      final object = manager.fetch<String>(SettingType.unknown);

      await awaitForSetting(object, defaultValue);
      expect(object.state, defaultValue);

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

// Helper function for awaiting for a setting to change. If the setting is
// already at the expected value, then the function immediately returns.
Future<void> awaitForSetting(SettingSource source, Object expectedValue) async {
  if (source.state == expectedValue) {
    return;
  }

  final Completer<void> completer = Completer<void>();
  source.addListener(completer.complete);
  await completer.future;
  source.removeListener(completer.complete);
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
    Completer<void> completer = new Completer<void>();
    item.removeListener(notifyListeners);
    open = false;
    completer.complete();
    return completer.future;
  }

  @override
  Future<void> initialize() async {
    Completer<void> completer = new Completer<void>();
    item.addListener(notifyListeners);
    open = true;
    completer.complete();
    return completer.future;
  }

  @override
  Future<bool> setSettingValue(SettingsObject value) async {
    item.value = value.data.stringValue;
    return true;
  }

  @override
  Future<ReturnCode> mutate(Mutation mutation,
      {MutationHandles handles}) async {
    if (mutation.tag != MutationTag.stringMutationValue) {
      return ReturnCode.unsupported;
    }

    item.value = mutation.stringMutationValue.value;
    return ReturnCode.ok;
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
