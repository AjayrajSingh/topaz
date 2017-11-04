import 'dart:async';

import 'package:dashboard/buildbucket/build_bucket_service.dart';
import 'package:dashboard/service/build_info.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:buildbucket/buildbucket.dart';

void main() {
  group(BuildBucketService, () {
    BuildBucketService service;
    MockBuildBucketApi mockApi;

    const String buildName = 'fuchsia-x86_64-linux-release';

    ApiCommonBuildMessage buildInfoResponse =
        new ApiCommonBuildMessage.fromJson(<String, Object>{
      'bucket': 'luci.fuchsia.continuous',
      'status': 'COMPLETE',
      'result': 'SUCCESS',
      'tags': const <String>[
        'builder:fuchsia-x86_64-linux-release:1509636609227930',
      ],
      'url': '#2',
    });

    setUp(() {
      mockApi = new MockBuildBucketApi();
      service = new BuildBucketService(mockApi);
    });

    test('getBucketByName should fetch build info based on the given name',
        () async {
      when(mockApi.search(
        bucket: const <String>['luci.fuchsia.continuous'],
        status: 'COMPLETED',
        tag: <String>['builder:$buildName'],
      )).thenReturn(new Future<ApiSearchResponseMessage>.value(
          new ApiSearchResponseMessage()
            ..builds = <ApiCommonBuildMessage>[buildInfoResponse]));

      final BuildInfo info = await service.getBuildByName(buildName).first;

      expect(info.bucket, 'luci.fuchsia.continuous');
      expect(info.status, 'COMPLETE');
      expect(info.result, 'SUCCESS');
      expect(info.name, 'fuchsia-x86_64-linux-release');
      expect(info.url, '#2');
      expect(info.type, 'fuchsia');
    });

    test('getBuildsByname should fetch build info based on the given names',
        () async {
      when(mockApi.search(
        bucket: const <String>['luci.fuchsia.continuous'],
        status: 'COMPLETED',
        tag: <String>['builder:$buildName'],
      )).thenReturn(new Future<ApiSearchResponseMessage>.value(
          new ApiSearchResponseMessage()
            ..builds = <ApiCommonBuildMessage>[buildInfoResponse]));

      final List<BuildInfo> results =
          await service.getBuildsByName(<String>[buildName]).first;
      final BuildInfo info = results.single;

      expect(info.bucket, 'luci.fuchsia.continuous');
      expect(info.status, 'COMPLETE');
      expect(info.result, 'SUCCESS');
      expect(info.name, 'fuchsia-x86_64-linux-release');
      expect(info.url, '#2');
      expect(info.type, 'fuchsia');
    });
  });
}

/// Mock [BuildbucketApi] implementation.
class MockBuildBucketApi extends Mock implements BuildbucketApi {}
