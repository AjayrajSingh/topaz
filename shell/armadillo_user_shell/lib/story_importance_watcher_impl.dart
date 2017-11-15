// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:lib.story.fidl/story_provider.fidl.dart';

/// Watches for changes to story importance.
class StoryImportanceWatcherImpl extends StoryImportanceWatcher {
  /// Called when the importance of stories change.
  final VoidCallback onImportanceChanged;

  /// Constructor.
  StoryImportanceWatcherImpl({this.onImportanceChanged});

  @override
  void onImportanceChange() => onImportanceChanged?.call();
}
