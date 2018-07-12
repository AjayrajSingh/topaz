// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../buildbucket/build_bucket_service.dart';
import 'build_info.dart';

/// Used to fetch build information.
abstract class BuildService {
  /// Default constructor.
  factory BuildService() => new BuildBucketService();

  /// The percentage of requests made by this service that have timed out.
  double get timeoutRate;

  /// Returns a single event stream of the latest [BuildInfo] for [buildName].
  ///
  /// The stream interface is used so that the client may cancel requests.
  Stream<BuildInfo> getBuildByName(String buildName);

  /// Returns a stream of the latest [BuildInfo] for the given [buildNames].
  ///
  /// The stream interface is used so that the client may cancel requests.
  Stream<List<BuildInfo>> getBuildsByName(List<String> buildNames);
}

/// An exception thrown when a [BuildService] operation fails.
class BuildServiceException implements Exception {
  /// This exception's message.
  final String message;

  /// Const constructor.
  const BuildServiceException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}
