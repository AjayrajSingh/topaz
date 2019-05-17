// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'module_info.g.dart';

/// A class that stores information about a module.
@JsonSerializable()
class ModuleInfo {
  /// The surface id.
  final String modName;

  /// The intent that triggered the creation of this mod.
  final String intent;

  /// List of parameter ids input to this mod.
  @JsonKey(
      fromJson: _unmodifiableListViewFromJson,
      toJson: _unmodifiableListViewToJson)
  final UnmodifiableListView<String> parameters;

  /// Constructor for the module info information object.
  ModuleInfo({
    @required this.modName,
    @required this.intent,
    @required this.parameters,
  });

  static UnmodifiableListView<String> _unmodifiableListViewFromJson(
          List<dynamic> parameters) =>
      UnmodifiableListView<String>(parameters.cast<String>());

  static List<String> _unmodifiableListViewToJson(
          UnmodifiableListView<String> parameters) =>
      parameters.toList();

  @override
  String toString() => 'modName: $modName, intent: $intent';

  /// Load this model from a json object.
  factory ModuleInfo.fromJson(Map<String, dynamic> json) =>
      _$ModuleInfoFromJson(json);

  /// Serialize this model as json
  Map<String, dynamic> toJson() => _$ModuleInfoToJson(this);
}
