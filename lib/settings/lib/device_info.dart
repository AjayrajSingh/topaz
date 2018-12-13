import 'dart:async';
import 'dart:io';
import 'package:fidl_fuchsia_devicesettings/fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:meta/meta.dart';

const String _lastUpdateFilePath = '/config/build-info/last-update';
const String _factoryResetKey = 'FactoryReset';

/// Class to provide device-specific details, such as build information.
class DeviceInfo {
  DateTime _sourceTimeStamp;
  DateTime get sourceTimeStamp => _sourceTimeStamp;

  /// Returns the date the source code was last updated.
  static DateTime getSourceDate() {
    final File updateFile = new File(_lastUpdateFilePath);

    if (updateFile.existsSync()) {
      final String lastUpdate = updateFile.readAsStringSync();

      try {
        return DateTime.parse(lastUpdate.trim());
      } on FormatException {
        log.warning('Could not parse build timestamp!');
      }
    } else {
      log.warning('Update file not present');
    }

    return null;
  }

  /// Determines whether the factory reset flag has been set.
  ///
  /// Completes as true if the factory reset flag is present, false otherwise.
  static Future<bool> getFactoryResetFlag() async {
    final completer = Completer<bool>();
    final deviceSettingsManagerProxy = DeviceSettingsManagerProxy();

    connectToService(StartupContext.fromStartupInfo().environmentServices,
        deviceSettingsManagerProxy.ctrl);
    deviceSettingsManagerProxy.getInteger(_factoryResetKey,
        (int resetFlagValue, Status s) {
      deviceSettingsManagerProxy.ctrl.close();
      completer.complete(s == Status.ok && resetFlagValue > 0);
    });
    return completer.future;
  }

  /// Sets a flag to determine whether the device should be reset to factory
  /// settings or not.
  ///
  /// [shouldReset] specifies whether the flag should be set or not. Will
  /// complete with true if the flag was set successfully and false otherwise.
  static Future<bool> setFactoryResetFlag({@required bool shouldReset}) async {
    final resetFlagValue = shouldReset ? 1 : 0;
    final completer = Completer<bool>();
    final deviceSettingsManagerProxy = DeviceSettingsManagerProxy();

    connectToService(StartupContext.fromStartupInfo().environmentServices,
        deviceSettingsManagerProxy.ctrl);
    deviceSettingsManagerProxy.setInteger(_factoryResetKey, resetFlagValue,
        (bool result) {
      deviceSettingsManagerProxy.ctrl.close();
      completer.complete(result);
    });
    return completer.future;
  }
}
