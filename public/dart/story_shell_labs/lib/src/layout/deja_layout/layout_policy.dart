// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:tiler/tiler.dart';

import '../tile_model/module_info.dart';
import 'layout_store.dart';
import 'layout_utils.dart';

const _kGroups = 4;

/// Layout Policy for adding new content to a [TilerModel].
///
/// The strategy is to first find prior [TilerModel]s that have
/// the same intents.  Then group these candidates by equivalent layout
/// geometry (ignoring flex). Proceed by taking the largest group and picking
/// the most popular dimensional layout (looking at flex) within that group.
///
/// Second and third choice layouts are found in the smaller equivalent
/// geometry groups.
///
/// If there are no prior examples with similar intents then the policy
/// uses "split largest."
class LayoutPolicy {
  /// Storage for layout history data.
  final LayoutStore layoutStore;

  /// A tiling layout policy.
  LayoutPolicy({this.layoutStore});

  /// Returns new layouts suggestions for either add mod or remove mod.
  List<TilerModel<ModuleInfo>> getLayout(TilerModel<ModuleInfo> a) {
    var candidates = layoutStore.listSync();

    // Collect the trees with same intents
    candidates = _intentReduce(a, candidates);
    print('Candidates intent count ${candidates.length}');
    if (candidates.isEmpty) {
      return [a];
    }
    // Group into lists of trees with the equivalent geometry
    final gGroups =
        _hashGroup(layoutFiles: candidates, includeFlex: false, n: _kGroups);
    print('Geometry group ${gGroups.length}');
    if (gGroups.isEmpty) {
      return [a];
    }
    // For the top N geometry groups, find a single "popular" tree to return
    final result = <TilerModel<ModuleInfo>>[];
    for (int i = 0; i < min(gGroups.length, _kGroups); i++) {
      // Group the trees having equivalent geometry and flex (trees are the same)
      final fGroups =
          _hashGroup(layoutFiles: gGroups[i], includeFlex: true, n: 1);
      print('Flex group count ${fGroups.length}');
      // THe result is the most popular layout with flex
      result.add(layoutStore.read(fGroups.first.first));
    }
    // A list of trees, each with a unique geometry.
    // Update the modName references and return.
    for (final tileModel in result) {
      updateModNames(a, tileModel);
    }
    return result;
  }

  /// Write a model to the storage.
  void write(TilerModel a) {
    layoutStore.write(a);
  }

  /// Reduce the candidate layouts to ones where the intents match.
  List<File> _intentReduce(TilerModel<ModuleInfo> a, List<File> candidates) {
    return candidates
        .where((file) => compareIntents(a, layoutStore.read(file)))
        .toList();
  }

  /// Return N largest hash equivalent groups among the layouts files.
  ///
  /// The input is a list of layout files, and the output is a
  /// list of hash equivalent groups in length order.
  ///
  /// For example, can return the layout [File]s for the N most popular
  /// geometrically equivalent layouts.
  List<List<File>> _hashGroup(
      {List<File> layoutFiles, bool includeFlex, int n}) {
    if (layoutFiles.length <= 1) {
      return [layoutFiles];
    }
    final map = HashMap<int, List<File>>();
    // Accumulate the files for each group
    for (final file in layoutFiles) {
      int hashCode = treeHashCode(
          model: layoutStore.read(file), includeFlex: includeFlex);
      // Self initializing hash table idiom
      final value = map[hashCode];
      map[hashCode] = (value == null) ? [file] : value + [file];
    }

    // Sort by descending occurence count.
    return map.values.toList()
      ..sort((b, a) => a.length.compareTo(b.length))
      ..take(n);
  }
}
