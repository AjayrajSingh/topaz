// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_setui/fidl.dart';
import 'package:lib_setui_settings_common/setting_adapter.dart';
import 'package:lib_setui_settings_common/setting_source.dart';

typedef LogAction = void Function();
typedef LogExecutor = void Function(Duration delay, LogAction action);

/// An adapter that can be preconfigured to return set values.
class MockSettingAdapter implements SettingAdapter {
  final Map<SettingType, SettingSource> _sources = {};
  final Map<int, Completer<UpdateResponse>> _activeResponses = {};
  final Map<int, Completer<MutationResponse>> _activeMutationResponses = {};
  final List<AdapterLog> logs;
  final LogExecutor executor;

  /// Default constructor to execute provided [AdapterLog]s. A [LogExecutor] may
  /// be provided to override the default behavior of executing server logs
  /// based on their time relationship with the closest user action keyframe.
  MockSettingAdapter(this.logs, {this.executor = _logExecute});

  @override
  SettingSource<T> fetch<T>(SettingType settingType) {
    if (!_sources.containsKey(settingType)) {
      _sources[settingType] = SettingSource<T>();
    }

    // Immediately unwind to the matching fetch
    _unwindTo((AdapterLog log) =>
        log.type == AdapterLogType.fetch && log.fetchLog.type == settingType);

    if (logs.isNotEmpty) {
      // Unwind in relation to the found fetch log.
      final AdapterLog log = logs.removeAt(0);
      _unwindTo((AdapterLog log) => log.fromClient, keyFrame: log.time);
    }
    return _sources[settingType];
  }

  @override
  Future<UpdateResponse> update(SettingsObject updatedSetting) {
    final Completer<UpdateResponse> completer = Completer<UpdateResponse>();

    // Unwind to the matching update log.
    _unwindTo((AdapterLog log) {
      return log.type == AdapterLogType.update &&
          log.updateLog.settings.settingType == updatedSetting.settingType;
    });

    if (logs.isEmpty) {
      completer.complete(null);
    } else {
      final AdapterLog log = logs.removeAt(0);

      _activeResponses[log.updateLog.id] = completer;

      // Unwind to the next client log.
      _unwindTo((AdapterLog log) => log.fromClient, keyFrame: log.time);
    }
    return completer.future;
  }

  @override
  Future<MutationResponse> mutate(SettingType settingType, Mutation mutation,
      {MutationHandles handles}) {
    final Completer<MutationResponse> completer = Completer<MutationResponse>();

    // Unwind to the matching update log.
    _unwindTo((AdapterLog log) {
      return log.type == AdapterLogType.mutation &&
          log.mutationLog.settingType == settingType;
    });

    if (logs.isEmpty) {
      completer.complete(null);
    } else {
      final AdapterLog log = logs.removeAt(0);

      _activeMutationResponses[log.mutationLog.id] = completer;

      // Unwind to the next client log.
      _unwindTo((AdapterLog log) => log.fromClient, keyFrame: log.time);
    }
    return completer.future;
  }

  /// Replays logs up to the log which matches the conditions provided by the
  /// input match function. The keyframe provides a time reference which events
  /// will be temporally executed against.
  void _unwindTo(bool match(AdapterLog log), {DateTime keyFrame}) {
    while (logs.isNotEmpty && !match(logs.first)) {
      _processLog(keyFrame, logs.removeAt(0));
    }
  }

  void _processLog(DateTime keyFrame, AdapterLog log) {
    LogAction action;

    switch (log.type) {
      case AdapterLogType.response:
        action = () {
          final Completer completer =
              _activeResponses[log.responseLog.updateId];
          if (completer == null) {
            return;
          }

          completer.complete(log.responseLog.response);
        };
        break;
      case AdapterLogType.mutationResponse:
        action = () {
          final Completer completer =
              _activeMutationResponses[log.mutationResponseLog.mutationId];
          if (completer == null) {
            return;
          }

          completer.complete(log.mutationResponseLog.response);
        };
        break;
      case AdapterLogType.setting:
        action = () => _sources[log.settingLog.settings.settingType]
            .notify(log.settingLog.settings);
        break;
    }

    if (action != null) {
      executor(keyFrame != null ? log.time.difference(keyFrame) : Duration.zero,
          action);
    }
  }

  /// Default playback mechanism, executing action after specified delay.
  static void _logExecute(Duration delay, LogAction action) {
    Future.delayed(delay, action);
  }
}
