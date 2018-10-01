import 'dart:typed_data';

import 'package:fidl/src/interface.dart';
import 'package:fidl_fuchsia_setui/fidl.dart';
import 'package:fidl_fuchsia_wlan_mlme/fidl.dart' as mlme;
import 'package:fidl_fuchsia_wlan_service/fidl.dart';
import 'package:lib_setui_service/src/network_controller.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

// ignore_for_file: implementation_imports

const String defaultValue = 'default';

const String value1 = 'value1';

void main() async {
  NetworkController controller;
  MockWlanProxy proxy;
  SettingListenerObject object;

  setUp(() async {
    proxy = MockWlanProxy();
    controller = NetworkController();
    object = SettingListenerObject();

    controller.listeners.add(object);
    controller.active = true;
  });

  group('Network controller', () {
    test('can get settings object', () async {
      when(proxy.status(any)).thenAnswer((invocation) {
        void Function(WlanStatus) callback =
            invocation.positionalArguments.first;
        callback(_status());
      });

      when(proxy.scan(any, any)).thenAnswer((invocation) {
        void Function(ScanResult) callback = invocation.positionalArguments[1];
        callback(
            ScanResult(error: Error(code: ErrCode.ok, description: ''), aps: [
          _buildAp('a', rssiDbm: 11),
          // Should be deduped by the other one
          _buildAp('a', rssiDbm: 5),
          // Shouldn't be included because incompatible
          _buildAp('b', isCompatible: false),
          _buildAp('c', isSecure: true)
        ]));
      });

      await controller.initializeWithService(() async => proxy);

      final settingsObject = controller.value;

      expect(settingsObject.settingType, SettingType.wireless);
      expect(settingsObject.data.wireless, isNotNull);
      expect(settingsObject.data.wireless.accessPoints.length, 2);

      int matchedPoints = 0;
      for (WirelessAccessPoint accessPoint
          in settingsObject.data.wireless.accessPoints) {
        if (accessPoint.name == 'a') {
          matchedPoints++;
          expect(accessPoint.rssi, 11);
          expect(accessPoint.security, WirelessSecurity.unsecured);
        } else if (accessPoint.name == 'c') {
          matchedPoints++;
          expect(accessPoint.rssi, 8);
          expect(accessPoint.security, WirelessSecurity.secured);
        }
      }
      expect(matchedPoints, 2);
    });

    test('will call service when disconnecting', () async {
      when(proxy.status(any)).thenAnswer((invocation) {
        void Function(WlanStatus) callback =
            invocation.positionalArguments.first;
        callback(WlanStatus(
            error: Error(code: ErrCode.ok, description: ''),
            state: State.associated,
            currentAp: _buildAp('a')));
      });

      await controller.initializeWithService(() async => proxy);
      final currentAp = controller.value.data.wireless.accessPoints.first;

      when(proxy.disconnect(any)).thenAnswer((invocation) {
        void Function(Error) callback = invocation.positionalArguments.first;
        callback(Error(code: ErrCode.ok, description: ''));
      });

      await controller.setSetting(SettingsObject(
          settingType: SettingType.wireless,
          data: SettingData.withWireless(WirelessState(accessPoints: [
            WirelessAccessPoint.clone(currentAp,
                status: ConnectionStatus.disconnected)
          ]))));

      verify(proxy.disconnect(any)).called(1);
    });

    test('will call service when connecting', () async {
      const password = 'password';

      when(proxy.status(any)).thenAnswer((invocation) {
        void Function(WlanStatus) callback =
            invocation.positionalArguments.first;
        callback(_status());
      });

      when(proxy.scan(any, any)).thenAnswer((invocation) {
        void Function(ScanResult) callback = invocation.positionalArguments[1];
        callback(ScanResult(
            error: Error(code: ErrCode.ok, description: ''),
            aps: [_buildAp('c', isSecure: true)]));
      });

      await controller.initializeWithService(() async => proxy);
      final currentAp = controller.value.data.wireless.accessPoints.first;

      when(proxy.connect(any, any)).thenAnswer((invocation) {
        final ConnectConfig connectConfig =
            invocation.positionalArguments.first;

        expect(connectConfig.passPhrase, password);

        void Function(Error) callback = invocation.positionalArguments[1];
        callback(Error(code: ErrCode.ok, description: ''));
      });

      await controller.setSetting(SettingsObject(
          settingType: SettingType.wireless,
          data: SettingData.withWireless(WirelessState(accessPoints: [
            WirelessAccessPoint.clone(currentAp,
                password: password, status: ConnectionStatus.connected)
          ]))));

      verify(proxy.connect(any, any)).called(1);
    });
  });

  tearDown(() {
    controller.close();
  });
}

WlanStatus _status() {
  return WlanStatus(
      error: Error(code: ErrCode.ok, description: ''), state: State.scanning);
}

Ap _buildAp(String ssid,
        {bool isCompatible = true, bool isSecure = false, int rssiDbm = 8}) =>
    Ap(
      ssid: ssid,
      rssiDbm: rssiDbm,
      chan: mlme.WlanChan(primary: 32, secondary80: 18, cbw: mlme.Cbw.cbw80),
      isCompatible: isCompatible,
      isSecure: isSecure,
      bssid: Uint8List.fromList([32, 0]),
    );

class MockWlanProxy extends Mock implements WlanProxy {}

class MockProxyController<T> extends Mock implements ProxyController<T> {}

class SettingListenerObject implements SettingListenerProxy {
  SettingsObject object;
  MockProxyController<SettingListener> controller =
      MockProxyController<SettingListener>();

  SettingListenerObject() {
    when(controller.isBound).thenReturn(true);
  }

  @override
  ProxyController<SettingListener> get ctrl => controller;

  // This shouldn't be a setter since it overrides a different field.
  // ignore: use_setters_to_change_properties
  @override
  void notify(SettingsObject object) {
    this.object = object;
  }
}
