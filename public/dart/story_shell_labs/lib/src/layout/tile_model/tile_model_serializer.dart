// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:tiler/tiler.dart';

import 'module_info.dart';

/// Convert the tiler model to json.
Map<String, dynamic> toJson(TilerModel<ModuleInfo> model) => {
      'root': model.root == null ? null : _tileToJson(model.root),
    };

/// Parse the given JSON into a tiler model.
TilerModel<ModuleInfo> fromJson(Map<String, dynamic> json) =>
    TilerModel(root: _tileFromJson(json['root']));

Map<String, dynamic> _tileToJson(TileModel model) => {
      'content': model.content?.toJson(),
      'type': model.type.index,
      'flex': model.flex,
      'tiles': model.tiles.map(_tileToJson).toList(),
    };

TileModel<ModuleInfo> _tileFromJson(
  Map<String, dynamic> json, {
  TileModel parent,
}) {
  return TileModel(
    parent: parent,
    type: TileType.values[json['type']],
    content:
        (json['content'] == null) ? null : ModuleInfo.fromJson(json['content']),
    flex: json['flex'],
    tiles: _listTileFromJson(json['tiles']),
  );
}

List<TileModel<ModuleInfo>> _listTileFromJson(
  List<dynamic> json, {
  TileModel<ModuleInfo> parent,
}) {
  if (json != null) {
    return json.map((data) => _tileFromJson(data, parent: parent)).toList();
  }
  return [];
}

/// Creates a copy of the given tiler model.
TilerModel<ModuleInfo> cloneTiler(TilerModel<ModuleInfo> model) =>
    TilerModel<ModuleInfo>(
      root: _cloneTile(model.root),
    );

TileModel<ModuleInfo> _cloneTile(TileModel<ModuleInfo> model) => model == null
    ? null
    : TileModel(
        content: model.content,
        type: model.type,
        flex: model.flex,
        tiles: model.tiles.map(_cloneTile).toList(),
      );
