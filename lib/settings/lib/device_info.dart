import 'dart:async';
import 'dart:io';
import 'package:fidl_fuchsia_devicesettings/fidl_async.dart';
import 'package:fuchsia_logger/logger.dart';
import 'package:fuchsia_services/services.dart';
import 'package:meta/meta.dart';

const String _lastUpdateFilePath = '/config/build-info/latest-commit-date';
const String _factoryResetKey = 'FactoryReset';

/// Class to provide device-specific details, such as build information.
class DeviceInfo {
  DateTime _sourceTimeStamp;
  DateTime get sourceTimeStamp => _sourceTimeStamp;

  /// Returns the date the source code was last updated.
  static DateTime getSourceDate() {
    final File updateFile = File(_lastUpdateFilePath);

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

  /// Sets a flag to determine whether the device should be reset to factory
  /// settings or not.
  ///
  /// [shouldReset] specifies whether the flag should be set or not. Will
  /// complete with true if the flag was set successfully and false otherwise.
  static Future<bool> setFactoryResetFlag({@required bool shouldReset}) async {
    final resetFlagValue = shouldReset ? 1 : 0;
    final deviceSettingsManagerProxy = DeviceSettingsManagerProxy();

    StartupContext.fromStartupInfo()
        .incoming
        .connectToService(deviceSettingsManagerProxy);
    final success = await deviceSettingsManagerProxy.setInteger(
        _factoryResetKey, resetFlagValue);
    deviceSettingsManagerProxy.ctrl.close();
    return success;
  }
}
