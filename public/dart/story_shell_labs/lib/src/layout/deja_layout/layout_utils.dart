// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:tiler/tiler.dart';
import '../tile_model/module_info.dart';

/// Utility for storing the size of a model.
class TileModelSize {
  /// The tiling model.
  final TileModel tile;

  /// Height ratio.
  final double heightFlex;

  /// Width ratio.
  final double widthFlex;

  /// Area of the til.
  double get area => heightFlex * widthFlex;

  /// Construtor
  TileModelSize(this.tile, this.heightFlex, this.widthFlex);

  @override
  String toString() => '$tile, $widthFlex, $heightFlex';
}

/// Find the [TileMode] that is holding the content or null if none.
TileModel findContent(TilerModel<ModuleInfo> a, String modName) {
  TileModel _recurse(TileModel<ModuleInfo> t) {
    if (t.type == TileType.content && t.content.modName == modName) {
      return t;
    } else {
      for (var child in t.tiles) {
        final t = _recurse(child);
        if (t != null) {
          return t;
        }
      }
    }
    return null;
  }

  return a.root != null ? _recurse(a.root) : null;
}

/// Find the largest tile by area in the tree
TileModel findLargestContent(TilerModel a) {
  TileModelSize _recurse(TileModelSize tms) {
    final tile = tms.tile;
    if (tile.type == TileType.content) {
      return tms;
    }
    double maxArea = 0.0;
    TileModelSize maxTms;
    // flex values for children need to be normalized by flex of all children.
    final sumFlex =
        tile.tiles.fold<double>(0.0, (total, child) => total + child.flex);
    for (final child in tile.tiles) {
      TileModelSize childTms;
      if (tile.type == TileType.row) {
        childTms = TileModelSize(
            child, tms.heightFlex, tms.widthFlex * child.flex / sumFlex);
      } else if (tile.type == TileType.column) {
        childTms = TileModelSize(
            child, tms.heightFlex * child.flex / sumFlex, tms.widthFlex);
      }
      final maxChildTms = _recurse(childTms);
      if (maxArea < maxChildTms.area) {
        maxTms = maxChildTms;
        maxArea = maxChildTms.area;
      }
    }
    return maxTms;
  }

  if (a.root.isEmpty) {
    return null;
  }

  final ts = _recurse(TileModelSize(a.root, 1.0, 1.0));
  return ts?.tile;
}

/// Returns a new tile after splitting the largest [tile] in the tree.
void splitLargestContent(TilerModel<ModuleInfo> a, ModuleInfo content) {
  if (a.root.isEmpty) {
    a.add(content: content);
  } else {
    final tile = findLargestContent(a);
    print('splitLargestContent - $tile - $content');
    a.split(tile: findLargestContent(a), content: content);
  }
  print('tiles are ${a.root}');
}

/// Returns a hashCode for the [TilerModel] with or without flex values
///
/// Note that dart does not include a hash combiner function so hashing of
/// objects is achieved by converting to a [String] which
/// has a content (not address) based [hashCode].
int treeHashCode({TilerModel<ModuleInfo> model, bool includeFlex}) {
  void _recurse(TileModel<ModuleInfo> tile, StringBuffer sb) {
    // Hash the type
    sb.write('t:${tile.type.index}');
    if (includeFlex) {
      sb.write('f:${tile.flex}');
    }
    if (tile.type == TileType.content) {
      // do not hash the module name
      sb.write('c:${tile.content.intent}');
    } else {
      sb.write('[');
      for (final t in tile.tiles) {
        _recurse(t, sb);
      }
      sb.write(']');
    }
  }

  final strBuffer = StringBuffer();
  _recurse(model.root, strBuffer);
  // String uses content for the hash
  return strBuffer.toString().hashCode;
}

/// Determine if two trees have the same geometry, ignoring flex.
bool compareGeometry(TileModel<ModuleInfo> a, TileModel<ModuleInfo> b) {
  if (a.type != b.type) {
    return false;
  } else if (a.type == TileType.content) {
    return true;
  } else {
    if (a.tiles.length != b.tiles.length) {
      return false;
    }
    for (int i = 0; i < a.tiles.length; i++) {
      if (!compareGeometry(a.tiles[i], b.tiles[i])) {
        return false;
      }
    }
  }
  return true;
}

/// Determine if two trees have the same geometry and flex.
bool compareFlex(TilerModel<ModuleInfo> a, TilerModel<ModuleInfo> b) {
  bool _recurse(TileModel<ModuleInfo> a, TileModel<ModuleInfo> b) {
    if (a.type != b.type) {
      return false;
    }
    if (a.type == TileType.content) {
      return true; // possibly a.flex == b.flex
    }
    if (a.flex != b.flex || a.tiles.length != b.tiles.length) {
      return false;
    }
    for (int i = 0; i < a.tiles.length; i++) {
      if (!_recurse(a.tiles[i], b.tiles[i])) {
        return false;
      }
    }
    return true;
  }

  if (!compareGeometry(a.root, b.root)) {
    return false;
  }
  return _recurse(a.root, b.root);
}

/// Determine if two trees have the same intents.
bool compareIntents(TilerModel<ModuleInfo> a, TilerModel<ModuleInfo> b) {
  final aIntents = _getIntents(a);
  final bIntents = _getIntents(b);
  if (aIntents.length != bIntents.length) {
    return false;
  }
  aIntents.forEach(bIntents.remove);
  return bIntents.isEmpty;
}

/// Gets the mods that have been removed from the old TileModel.
/// In editing mode, mods cannot be added.
Set<String> getModsDifference(
        TilerModel<ModuleInfo> oldTree, TilerModel<ModuleInfo> newTree) =>
    _getMods(oldTree).difference(_getMods(newTree));

/// Update modNames [from] [to], using intent as key and updating modName
void updateModNames(TilerModel<ModuleInfo> from, TilerModel<ModuleInfo> to) {
  final toTiles = getTileContent(to);
  final fromTiles = getTileContent(from);
  for (final toTile in toTiles) {
    final toIntent = toTile.content.intent;
    final fromTile = fromTiles.firstWhere((t) => t.content.intent == toIntent);
    fromTiles.remove(fromTile);
    final modName = fromTile.content.modName;
    final parameters = fromTile.content.parameters;
    toTile.content = ModuleInfo(
      intent: toIntent,
      modName: modName,
      parameters: parameters,
    );
  }
}

/// A co-routine to iterate over the TilerModel tree.
Iterable<TileModel> tilerWalker(TilerModel a) sync* {
  final nodes = ListQueue<TileModel>()..add(a.root);
  while (nodes.isNotEmpty) {
    nodes.addAll(nodes.first.tiles);
    yield nodes.removeFirst();
  }
}

/// Get the content nodes of a layout tree.
List<TileModel<ModuleInfo>> getTileContent(TilerModel<ModuleInfo> a) =>
    tilerWalker(a)
        .where((t) => t.type == TileType.content)
        .fold(<TileModel<ModuleInfo>>[], (l, t) => l..add(t));

// Get the modNames for the mods in the layout tree aka TileModel.
Set<String> _getMods(TilerModel<ModuleInfo> a) => tilerWalker(a)
    .where((t) => t.type == TileType.content)
    .fold(<String>{}, (s, t) => s..add(t.content.modName));

// Get the intents in a layout tree as an ordered list.
List<String> _getIntents(TilerModel<ModuleInfo> a) => tilerWalker(a)
    .where((t) => t.type == TileType.content)
    .fold(<String>[], (l, t) => l..add(t.content.intent))
      ..sort();
