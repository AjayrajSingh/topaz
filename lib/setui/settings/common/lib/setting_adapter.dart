// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_setui/fidl.dart';
import 'package:fidl_fuchsia_setui_json/json.dart';

import 'setting_source.dart';

/// An interface for accessing settings.
///
/// Adapters are meant for controllers, who expose a narrower interaction
/// surface to the clients.
abstract class SettingAdapter {
  /// Retrieves the current setting source.
  SettingSource<T> fetch<T>(SettingType settingType);

  /// Applies the updated values to the backend.
  Future<UpdateResponse> update(SettingsObject updatedSetting);

  /// Applies a mutation to the backend.
  Future<MutationResponse> mutate(SettingType settingType, Mutation mutation,
      {MutationHandles handles});
}

/// An interface for receiving setting updates.
abstract class AdapterLogger {
  /// Invoked when fetch is requested.
  void onFetch(FetchLog log);

  /// Invoked when an update occurs from the client.
  void onUpdate(UpdateLog log);

  /// Invoked when an update response is ready.
  void onResponse(ResponseLog log);

  /// Invoked when a mutation occurs from client.
  void onMutation(MutationLog log);

  /// Invoked when an mutation response is ready.
  void onMutationResponse(MutationResponseLog log);

  /// Invoked when a setting is updated from the server.
  void onSettingLog(SettingLog log);
}

/// Enum class for who is responsible for the update.
class AdapterLogType {
  static const int fetchId = 0;
  static const int updateId = 1;
  static const int settingId = 2;
  static const int responseId = 3;
  static const int mutationId = 4;
  static const int mutationResponseId = 5;

  final int value;

  factory AdapterLogType(int value) {
    switch (value) {
      case fetchId:
        return fetch;
      case updateId:
        return update;
      case settingId:
        return setting;
      case responseId:
        return response;
      case mutationId:
        return mutation;
      case mutationResponseId:
        return mutationResponse;
      default:
        return null;
    }
  }

  const AdapterLogType._(this.value);

  static const AdapterLogType fetch = const AdapterLogType._(fetchId);

  static const AdapterLogType update = const AdapterLogType._(updateId);

  static const AdapterLogType setting = const AdapterLogType._(settingId);

  static const AdapterLogType response = const AdapterLogType._(responseId);

  static const AdapterLogType mutation = const AdapterLogType._(mutationId);

  static const AdapterLogType mutationResponse =
      const AdapterLogType._(mutationResponseId);

  int toJson() {
    return value;
  }
}

/// Union container for an adapter log.
class AdapterLog {
  static const String _timeKey = 'time';
  static const String _typeKey = 'type';
  static const String _dataKey = 'data';

  static const String _fetchType = 'fetch';
  static const String _settingType = 'setting';
  static const String _responseType = 'response';
  static const String _updateType = 'update';
  static const String _mutationType = 'mutation';
  static const String _mutationResponseType = 'mutationResponse';

  final DateTime time;
  final AdapterLogType type;

  // ignore: prefer_typing_uninitialized_variables
  final _data;

  const AdapterLog.withFetch(this.time, FetchLog fetch)
      : _data = fetch,
        type = AdapterLogType.fetch;

  const AdapterLog.withUpdate(this.time, UpdateLog update)
      : _data = update,
        type = AdapterLogType.update;

  const AdapterLog.withSetting(this.time, SettingLog setting)
      : _data = setting,
        type = AdapterLogType.setting;

  const AdapterLog.withResponse(this.time, ResponseLog response)
      : _data = response,
        type = AdapterLogType.response;

  const AdapterLog.withMutation(this.time, MutationLog mutation)
      : _data = mutation,
        type = AdapterLogType.mutation;

  const AdapterLog.withMutationResponse(
      this.time, MutationResponseLog mutationResponse)
      : _data = mutationResponse,
        type = AdapterLogType.mutationResponse;

  factory AdapterLog.fromJson(Map<String, dynamic> json) {
    String type = json[_typeKey];
    DateTime time = DateTime.parse(json[_timeKey]);

    switch (type) {
      case _fetchType:
        return AdapterLog.withFetch(time, FetchLog?.fromJson(json[_dataKey]));
      case _updateType:
        return AdapterLog.withSetting(
            time, SettingLog?.fromJson(json[_dataKey]));
      case _settingType:
        return AdapterLog.withSetting(
            time, SettingLog?.fromJson(json[_dataKey]));
      case _responseType:
        return AdapterLog.withResponse(
            time, ResponseLog?.fromJson(json[_dataKey]));
      default:
        return null;
    }
  }

  String _typeToString() {
    switch (type) {
      case AdapterLogType.fetch:
        return _fetchType;
      case AdapterLogType.setting:
        return _settingType;
      case AdapterLogType.response:
        return _responseType;
      case AdapterLogType.update:
        return _updateType;
      case AdapterLogType.mutation:
        return _mutationType;
      case AdapterLogType.mutationResponse:
        return _mutationResponseType;
      default:
        return null;
    }
  }

  Map<String, dynamic> toJson() => {
        _timeKey: time.toIso8601String(),
        _typeKey: _typeToString(),
        _dataKey: _data,
      };

  bool get fromClient =>
      type == AdapterLogType.fetch || type == AdapterLogType.update;

  UpdateLog get updateLog {
    if (type != AdapterLogType.update) {
      return null;
    }

    return _data;
  }

  FetchLog get fetchLog {
    if (type != AdapterLogType.fetch) {
      return null;
    }

    return _data;
  }

  SettingLog get settingLog {
    if (type != AdapterLogType.setting) {
      return null;
    }

    return _data;
  }

  ResponseLog get responseLog {
    if (type != AdapterLogType.response) {
      return null;
    }

    return _data;
  }

  MutationLog get mutationLog => type == AdapterLogType.mutation ? _data : null;

  MutationResponseLog get mutationResponseLog =>
      type == AdapterLogType.mutationResponse ? _data : null;
}

class FetchLog {
  static const String _typeKey = 'type';

  final SettingType type;

  FetchLog(this.type);

  factory FetchLog.fromJson(Map<String, dynamic> json) => json != null
      ? FetchLog(SettingTypeConverter.fromJson(json[_typeKey]))
      : null;

  Map<String, dynamic> toJson() =>
      {_typeKey: SettingTypeConverter.toJson(type)};
}

/// A container for capturing details around a service response.
class ResponseLog {
  static const String _updateIdKey = 'update_id';
  static const String _responseKey = 'response';

  final int updateId;
  final UpdateResponse response;

  ResponseLog(this.updateId, this.response);

  factory ResponseLog.fromJson(Map<String, dynamic> json) => json != null
      ? ResponseLog(json[_updateIdKey],
          UpdateResponseConverter.fromJson(json[_responseKey]))
      : null;

  Map<String, dynamic> toJson() => {
        _updateIdKey: updateId,
        _responseKey: UpdateResponseConverter.toJson(response)
      };
}

/// A container for capturing interaction events between the client and service.
class SettingLog {
  static const String _settingsKey = 'settings';

  /// The captured settings.
  final SettingsObject settings;

  SettingLog(this.settings);

  factory SettingLog.fromJson(Map<String, dynamic> json) =>
      SettingLog(SettingsObjectConverter.fromJson(json[_settingsKey]));

  Map<String, dynamic> toJson() => {
        _settingsKey: SettingsObjectConverter.toJson(settings),
      };
}

class UpdateLog {
  static const String _idKey = 'id';
  static const String _settingsKey = 'settings';

  final int id;
  final SettingsObject settings;

  UpdateLog(this.id, this.settings);

  factory UpdateLog.fromJson(Map<String, dynamic> json) => UpdateLog(
      json[_idKey], SettingsObjectConverter.fromJson(json[_settingsKey]));

  Map<String, dynamic> toJson() => {
        _idKey: id,
        _settingsKey: SettingsObjectConverter.toJson(settings),
      };
}

class MutationLog {
  static const String _idKey = 'id';
  static const String _settingTypeKey = 'settingType';
  static const String _mutationKey = 'mutation';

  final int id;
  final SettingType settingType;
  final Mutation mutation;

  MutationLog(this.id, this.settingType, this.mutation);

  factory MutationLog.fromJson(Map<String, dynamic> json) => MutationLog(
      json[_idKey],
      SettingTypeConverter.fromJson(json[_settingTypeKey]),
      MutationConverter.fromJson(json[_mutationKey]));

  Map<String, dynamic> toJson() => {
        _idKey: id,
        _settingTypeKey: SettingTypeConverter.toJson(settingType),
        _mutationKey: MutationConverter.toJson(mutation),
      };
}

class MutationResponseLog {
  static const String _mutationIdKey = 'mutation_id';
  static const String _responseKey = 'response';

  final int mutationId;
  final MutationResponse response;

  MutationResponseLog(this.mutationId, this.response);

  factory MutationResponseLog.fromJson(Map<String, dynamic> json) =>
      json != null
          ? MutationResponseLog(json[_mutationIdKey],
              MutationResponseConverter.fromJson(json[_responseKey]))
          : null;

  Map<String, dynamic> toJson() => {
        _mutationIdKey: mutationId,
        _responseKey: UpdateResponseConverter.toJson(response)
      };
}
