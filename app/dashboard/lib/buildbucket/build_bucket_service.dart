// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:buildbucket/buildbucket.dart';
import 'package:dashboard/enums.dart';
import 'package:http/http.dart' as http;

import 'package:dashboard/service/build_info.dart';
import 'package:dashboard/service/build_service.dart';

/// Provides a [BuildbucketApi].
typedef _ApiProvider = BuildbucketApi Function(http.Client client);

/// A [BuildService] implementation that fetches info from the build_bucket api.
class BuildBucketService implements BuildService {
  static const Duration _timeoutDuration = const Duration(seconds: 10);
  static const List<String> _allBuckets = const <String>[
    'luci.fuchsia.ci',
  ];

  int _requestCount = 0;
  int _timeoutCount = 0;

  _ApiProvider _createApi;

  /// Initializing constructor.
  BuildBucketService({_ApiProvider apiProvider})
      : _createApi = apiProvider ?? _defaultApiFactory;

  @override
  double get timeoutRate =>
      100 * (_requestCount > 0 ? _timeoutCount / _requestCount : 0.0);

  @override
  Stream<BuildInfo> getBuildByName(String buildName) async* {
    http.Client httpClient;
    ApiSearchResponseMessage response;
    try {
      // Create a new HTTP client per request to prevent opening infinite sockets.
      httpClient = new http.Client();

      final Future<ApiSearchResponseMessage> request =
          _createApi(httpClient).search(
        bucket: _allBuckets,
        tag: <String>['builder:$buildName'],
        status: BuildStatusEnum.completed.value,
      );
      _requestCount++;

      response = await request.timeout(_timeoutDuration, onTimeout: () {
        _timeoutCount++;
        throw new TimeoutException(
            '$buildName exceeded ${_timeoutDuration.inSeconds} seconds');
      });
    } finally {
      httpClient?.close();
    }

    if (response?.error != null) {
      throw new BuildServiceException(response.error.toJson().toString());
    }

    yield _createBuildInfo(response.builds.first);
  }

  /// Fetch builds with names from [buildNames].
  ///
  /// On build bucket, this given build name corresponds to the name of the
  /// builder which is derived from the build response's tags.
  @override
  Stream<List<BuildInfo>> getBuildsByName(List<String> buildNames) async* {
    yield await Future
        .wait(buildNames.map((String name) => getBuildByName(name).first));
  }

  /// Creates a new [BuildbucketApi] given [httpClient].
  static BuildbucketApi _defaultApiFactory(http.Client httpClient) =>
      new BuildbucketApi(httpClient);

  /// Returns the "name" of the build if it is present. Otherwise, null.
  String _getBuildName(ApiCommonBuildMessage build) {
    return build.tags?.isNotEmpty == true
        ? build.tags.first.split(':')[1]
        : null;
  }

  String _getBuildType(ApiCommonBuildMessage build) {
    return _getBuildName(build).split('-').first;
  }

  BuildInfo _createBuildInfo(ApiCommonBuildMessage build) => new BuildInfo(
        bucket: build.bucket,
        name: _getBuildName(build),
        result: BuildResultEnum.from(build.result),
        status: BuildStatusEnum.from(build.status),
        type: _getBuildType(build),
        url: build.url,
      );
}
