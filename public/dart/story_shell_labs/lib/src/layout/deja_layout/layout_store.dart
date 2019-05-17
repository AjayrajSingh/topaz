// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:tiler/tiler.dart';

import '../tile_model/module_info.dart';
import '../tile_model/tile_model_serializer.dart' show fromJson, toJson;

/// Persistent storage for layouts
class LayoutStore {
  /// Directory path where the data will be persisted.
  final String directory;

  /// Maximum amount of files to store.
  final int size;

  /// Constructor for layout storage.
  LayoutStore({this.directory = '/data/layouts', this.size = 100});

  /// Clears the storage.
  ///
  /// Synchronously deletes all the [File]s in the layout storage.
  void deleteSync() {
    try {
      print('LayoutStore deleting $directory');
      File(directory).deleteSync(recursive: true);
    } on FileSystemException catch (e) {
      print('LayoutStore Failed to delete $directory: $e');
    }
  }

  /// Get a list of file names in the storage containg [TilerModel]s.
  ///
  /// Returns a List containing [File] objects.
  List<File> listSync() {
    try {
      final result = Directory(directory)
          .listSync()
          .whereType<File>()
          .cast<File>()
          .toList();
      print('listSync: ${result.length} ${result.map((f) => f.path)}');
      return result;
    } on FileSystemException catch (_) {
      // No such file or directory
      return [];
    }
  }

  /// Write the [TilerModel] to persistent storage.
  void write(TilerModel<ModuleInfo> a) {
    if (a.root != null) {
      String now = DateTime.now().toIso8601String();
      File(path.join(directory, now))
        ..createSync(recursive: true)
        ..writeAsString(json.encode(toJson(a)));
      _prune();
    }
  }

  /// Read the [TilerModel] from persistent storage.
  TilerModel<ModuleInfo> read(File f) {
    String s = f.readAsStringSync();
    return fromJson(jsonDecode(s));
  }

  // Prune old files from the storage.
  void _prune() {
    int _compare(File a, File b) =>
        a.lastModifiedSync().compareTo(b.lastModifiedSync());

    final files = listSync();
    print('Pruning file(s): $files');
    files.sort(_compare);
    for (final file in files.skip(size)) {
      file.deleteSync();
    }
  }
}
