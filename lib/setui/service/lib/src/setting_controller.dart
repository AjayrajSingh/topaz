import 'dart:async';

import 'package:fidl_fuchsia_setui/fidl.dart';

/// Controller for a specific setting.
///
/// The service instantiates [SettingController]s mapped to [SettingType]s.
abstract class SettingController {
  final List<SettingListenerProxy> listeners = [];

  void addListener(SettingListenerProxy listener) {
    if (listeners.isEmpty) {
      initialize();
    }
    listeners.add(listener);
    listener.notify(value);
  }

  void notifyListeners() {
    listeners.removeWhere((listener) => !listener.ctrl.isBound);
    for (SettingListenerProxy listener in listeners) {
      listener.notify(value);
    }
    if (listeners.isEmpty) {
      close();
    }
  }

  /// Subclasses should not override this.
  ///
  /// They should override [setSettingValue] instead.
  Future<bool> setSetting(SettingsObject value) async {
    if (listeners.isEmpty) {
      await initialize();
    }
    final result = await setSettingValue(value);
    if (listeners.isEmpty) {
      await close();
    }
    return result;
  }

  /// Subclasses should override this to make the changes requested
  /// by setSettingValue, and return onbce complete.
  Future<bool> setSettingValue(SettingsObject value);

  Future<void> initialize();

  // Close should stop listening to any underlying services.
  // [initialize] and [close] can both be called multiple times during the
  // controller's lifetime
  Future<void> close();

  SettingsObject get value;
}
