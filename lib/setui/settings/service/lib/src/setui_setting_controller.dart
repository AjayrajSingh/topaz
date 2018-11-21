import 'dart:async';

import 'package:fidl_fuchsia_setui/fidl.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:meta/meta.dart';

/// Controller for a specific setting.
///
/// The service instantiates [SettingController]s mapped to [SettingType]s.
abstract class SetUiSettingController {
  final List<SettingListenerProxy> listeners = [];

  @visibleForTesting
  bool active = false;

  Future<void> addListener(SettingListenerProxy listener) async {
    if (listeners.isEmpty) {
      await _initialize();
    }
    listeners.add(listener);
    listener.notify(_getValue());
  }

  Future<void> notifyListeners() async {
    listeners.removeWhere((listener) => !listener.ctrl.isBound);
    for (SettingListenerProxy listener in listeners) {
      listener.notify(_getValue());
    }
    if (listeners.isEmpty) {
      await _close();
    }
  }

  /// Subclasses should not override this.
  ///
  /// They should override [setSettingValue] instead.
  Future<bool> setSetting(SettingsObject value) async {
    if (listeners.isEmpty) {
      await _initialize();
    }

    if (!active)
      throw StateError(
          'Attempted to set state with an uninitialized controller!');

    final result = await setSettingValue(value);
    if (listeners.isEmpty) {
      await _close();
    }
    return result;
  }

  Future<ReturnCode> mutate(Mutation mutation,
      {MutationHandles handles}) async {
    if (listeners.isEmpty) {
      await _initialize();
    }

    if (!active)
      throw StateError(
          'Attempted to mutate state with an uninitialized controller!');

    final result = await applyMutation(mutation, handles: handles);

    if (listeners.isEmpty) {
      await _close();
    }

    return result;
  }

  /// Subclasses should override this to make the changes requested
  /// by setSettingValue, and return once complete.
  Future<bool> setSettingValue(SettingsObject value);

  Future<ReturnCode> applyMutation(Mutation mutation,
      {MutationHandles handles}) {
    log.warning('mutation not implemented');
    final Completer<ReturnCode> completer = Completer<ReturnCode>()
      ..complete(ReturnCode.unsupported);
    return completer.future;
  }

  /// Initializes the controller.
  ///
  /// notifyListeners shouldn't be called in this function, or close
  /// will be immediately called due to lack of listeners.
  /// Subclasses should override to apply mutations. By default, the operation
  /// is ignored and a failure result is returned.
  Future<void> initialize();

  // Close should stop listening to any underlying services.
  // [initialize] and [close] can both be called multiple times during the
  // controller's lifetime
  Future<void> close();

  Future<void> _initialize() async {
    await initialize();
    active = true;
  }

  Future<void> _close() async {
    await close();
    active = false;
  }

  SettingsObject _getValue() {
    if (!active)
      throw StateError(
          'Attempted to retreive state from an uninitialized controller!');
    return value;
  }

  SettingsObject get value;
}
