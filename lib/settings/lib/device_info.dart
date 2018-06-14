import 'dart:io';

import 'package:lib.app.dart/logging.dart';

const String _lastUpdateFilePath = '/system/data/build/last-update';

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
}
