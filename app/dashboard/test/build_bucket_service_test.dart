// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:buildbucket/buildbucket.dart';
import 'package:dashboard/buildbucket/build_bucket_service.dart';
import 'package:dashboard/enums.dart';
import 'package:dashboard/service/build_info.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

void main() {
  group(BuildBucketService, () {
    BuildBucketService service;
    MockBuildBucketApi mockApi;

    const String buildName = 'fuchsia-x86_64-linux-release';

    ApiCommonBuildMessage buildInfoResponse =
        new ApiCommonBuildMessage.fromJson(<String, Object>{
      'bucket': 'luci.fuchsia.continuous',
      'status': BuildStatusEnum.completed.value,
      'result': BuildResultEnum.success.value,
      'tags': const <String>[
        'builder:fuchsia-x86_64-linux-release:1509636609227930',
      ],
      'url': '#2',
    });

    setUp(() {
      mockApi = new MockBuildBucketApi();
      service = new BuildBucketService(apiProvider: (_) => mockApi);
    });

    test('getBucketByName should fetch build info based on the given name',
        () async {
      when(mockApi.search(
        bucket: const <String>['luci.fuchsia.ci'],
        status: BuildStatusEnum.completed.value,
        tag: <String>['builder:$buildName'],
      )).thenAnswer((_) => new Future<ApiSearchResponseMessage>.value(
          new ApiSearchResponseMessage()
            ..builds = <ApiCommonBuildMessage>[buildInfoResponse]));

      final BuildInfo info = await service.getBuildByName(buildName).first;

      expect(info.bucket, 'luci.fuchsia.continuous');
      expect(info.status, BuildStatusEnum.completed);
      expect(info.result, BuildResultEnum.success);
      expect(info.name, 'fuchsia-x86_64-linux-release');
      expect(info.url, '#2');
      expect(info.type, 'fuchsia');
    });

    test('getBuildsByname should fetch build info based on the given names',
        () async {
      when(mockApi.search(
        bucket: const <String>['luci.fuchsia.ci'],
        status: BuildStatusEnum.completed.value,
        tag: <String>['builder:$buildName'],
      )).thenAnswer((_) => new Future<ApiSearchResponseMessage>.value(
          new ApiSearchResponseMessage()
            ..builds = <ApiCommonBuildMessage>[buildInfoResponse]));

      final List<BuildInfo> results =
          await service.getBuildsByName(<String>[buildName]).first;
      final BuildInfo info = results.single;

      expect(info.bucket, 'luci.fuchsia.continuous');
      expect(info.status, BuildStatusEnum.completed);
      expect(info.result, BuildResultEnum.success);
      expect(info.name, 'fuchsia-x86_64-linux-release');
      expect(info.url, '#2');
      expect(info.type, 'fuchsia');
    });
  });
}

/// Mock [BuildbucketApi] implementation.
class MockBuildBucketApi extends Mock implements BuildbucketApi {}
