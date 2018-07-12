// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../enums.dart';

/// Describes a build result.
class BuildInfo {
  /// The bucket this build belongs to.
  final String bucket;

  /// The status of the build.
  final BuildStatusEnum status;

  /// The result of the build.
  final BuildResultEnum result;

  /// The display name for the build.
  ///
  /// This usually corresponds to the environment information minus the project
  /// name. e.g. aarch64-linux-release.
  final String name;

  /// The url for retrieving build info.
  final String url;

  /// The type of build.
  ///
  /// This usually corresponds to the project.
  final String type;

  /// Const constructor.
  const BuildInfo({
    this.bucket,
    this.name,
    this.result,
    this.status,
    this.type,
    this.url,
  });
}
