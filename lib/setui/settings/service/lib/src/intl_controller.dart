// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_setui/fidl.dart';
import 'package:fidl_fuchsia_stash/fidl.dart';
import 'package:fidl_fuchsia_sys/fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:meta/meta.dart';
import 'intl/intl_settings_util.dart' as intl_util;

import 'setui_setting_controller.dart';

/// An implementation of [SetUiSettingController] for internationalization
/// settings. Currently uses Stash as a backing store.
class IntlSettingsController extends SetUiSettingController {
  static const String _stashStoreName = 'INTL_SETTINGS';
  @visibleForTesting
  static const String stashKey = 'INTL_SETTINGS_KEY';

  final StoreAccessorWrapperProvider _storeAccessorWrapperProvider;
  StoreAccessorWrapper _storeAccessorWrapper;
  IntlSettings _currentIntlSettings;

  /// Default constructor
  IntlSettingsController() : this.withStashProvider(createStoreAccessorWrapper);

  /// Constructor that takes a custom [StoreAccessorWrapperProvider], primarily
  /// for use in tests.
  IntlSettingsController.withStashProvider(
      StoreAccessorWrapperProvider storeAccessorWrapperProvider)
      : _storeAccessorWrapperProvider = storeAccessorWrapperProvider;

  @override
  Future<void> close() async {
    _storeAccessorWrapper.close();
    _currentIntlSettings = null;
  }

  @override
  Future<void> initialize() {
    Completer<void> completer = Completer();

    _storeAccessorWrapper = _storeAccessorWrapperProvider();
    _storeAccessorWrapper.accessor.getValue(stashKey, (value) {
      if (value != null && value.stringval != null) {
        // TODO: Parse error handling? Should the future ever fail?
        _currentIntlSettings = intl_util.fromJson(value.stringval);
      }
      completer.complete();
    });

    return completer.future;
  }

  @override
  SettingsObject get value => SettingsObject(
      settingType: SettingType.intl,
      data: SettingData.withIntl(_currentIntlSettings));

  @override
  Future<ReturnCode> applyMutation(Mutation mutation,
      {MutationHandles handles}) async {
    _currentIntlSettings =
        intl_util.applyMutation(_currentIntlSettings, mutation);
    final json = intl_util.toJson(_currentIntlSettings);
    _storeAccessorWrapper.accessor
      ..setValue(stashKey, Value.withStringval(json))
      ..commit();

    return ReturnCode.ok;
  }
}

/// Utility class that wraps an instance of Stash's [StoreAccessor], as well as
/// a function for closing it when [IntlSettingsController.close] is called.
abstract class StoreAccessorWrapper {
  StoreAccessor get accessor;

  StoreAccessorCloser get close;
}

/// Implementers should close any FIDL channels associated with a
/// [StoreAccessor].
typedef StoreAccessorCloser = void Function();

/// Implementers should provide a new instance of [StoreAccessorWrapper].
typedef StoreAccessorWrapperProvider = StoreAccessorWrapper Function();

class _StoreAccessorWrapperImpl extends StoreAccessorWrapper {
  final StoreAccessorProxy _storeAccessorProxy;
  final StoreAccessorCloser _closer;

  _StoreAccessorWrapperImpl(this._storeAccessorProxy, this._closer);

  @override
  StoreAccessor get accessor => _storeAccessorProxy;

  @override
  StoreAccessorCloser get close => _closer;
}

/// Default factory method for [StoreAccessorWrapper]. Connects to Stash and
/// requests a [StoreAccessor].
StoreAccessorWrapper createStoreAccessorWrapper() {
  ServiceProviderProxy environmentServices =
      StartupContext.fromStartupInfo().environmentServices;

  var storeProxy = StoreProxy();
  connectToService(environmentServices, storeProxy.ctrl);

  var storeAccessorProxy = StoreAccessorProxy();

  storeProxy
    ..identify(IntlSettingsController._stashStoreName)
    ..createAccessor(false, storeAccessorProxy.ctrl.request());

  connectToService(environmentServices, storeAccessorProxy.ctrl);

  void closer() {
    storeAccessorProxy.ctrl.close();
    storeProxy.ctrl.close();
  }

  return _StoreAccessorWrapperImpl(storeAccessorProxy, closer);
}
