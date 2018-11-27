import 'dart:async';

import 'package:fidl_fuchsia_setui/fidl.dart';
import 'package:fidl_fuchsia_timezone/fidl.dart';
import 'package:lib.app.dart/app.dart';

import 'setui_setting_controller.dart';

class TimeZoneController extends SetUiSettingController
    implements TimezoneWatcher {
  TimezoneProxy _timeZoneProxy;

  static const Map<String, TimeZone> _timeZones = {
    'US/Pacific': TimeZone(
        id: 'US/Pacific',
        name: 'Pacific Standard Time',
        region: ['San Francisco', 'Seattle', 'Los Angeles']),
    'US/Eastern': TimeZone(
        id: 'US/Eastern',
        name: 'Eastern Standard Time',
        region: ['Toronto', 'Detroit', 'New York']),
    'Europe/Paris': TimeZone(
        id: 'Europe/Paris',
        name: 'Central European Standard Time',
        region: ['Paris']),
    'Australia/Sydney': TimeZone(
        id: 'Australia/Sydney',
        name: 'Australian Eastern Standard Time',
        region: ['Sydney']),
  };

  String _currentTimeZoneId;

  @override
  Future<void> close() async {
    _timeZoneProxy.ctrl.close();
    _currentTimeZoneId = null;
  }

  @override
  Future<void> initialize() async {
    Completer<void> completer = Completer();

    _timeZoneProxy = TimezoneProxy();
    connectToService(StartupContext.fromStartupInfo().environmentServices,
        _timeZoneProxy.ctrl);

    _timeZoneProxy
      ..watch(TimezoneWatcherBinding().wrap(this))
      ..getTimezoneId((timezoneId) {
        _currentTimeZoneId = timezoneId;
        completer.complete();
      });

    return completer.future;
  }

  @override
  Future<ReturnCode> applyMutation(Mutation mutation,
      {MutationHandles handles}) async {
    assert(mutation.timeZoneMutationValue != null);

    final Completer<ReturnCode> completer = Completer<ReturnCode>();
    final currentTimeZone = mutation.timeZoneMutationValue.value.current;
    final newId = currentTimeZone != null ? currentTimeZone.id : 0;

    _timeZoneProxy.setTimezone(newId, (success) {
      completer.complete(ReturnCode.ok);
    });

    return completer.future;
  }

  @override
  SettingsObject get value => SettingsObject(
      settingType: SettingType.timeZone,
      data: SettingData.withTimeZoneValue(TimeZoneInfo(
          available: _timeZones.values.toList(),
          current: _timeZones[_currentTimeZoneId])));

  @override
  void onTimezoneOffsetChange(String timezoneId) {
    _currentTimeZoneId = timezoneId;
    notifyListeners();
  }
}
