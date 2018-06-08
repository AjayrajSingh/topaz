// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show base64;
import 'dart:io';

import 'package:mockito/mockito.dart';

// ignore_for_file: public_member_api_docs

/// A BASE64 encoded 1x1 transparent PNG image.
final List<int> _kTransparentImageBytes = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

/// Returns a mock HTTP client that responds with an image to all requests.
MockHttpClient createMockImageHttpClient(SecurityContext _) {
  final MockHttpClient client = new MockHttpClient();
  final MockHttpClientRequest request = new MockHttpClientRequest();
  final MockHttpClientResponse response = new MockHttpClientResponse();
  final MockHttpHeaders headers = new MockHttpHeaders();
  when(client.getUrl(typed(any))).thenReturn(new Future<HttpClientRequest>
                                 .value(request));
  when(request.headers).thenReturn(headers);
  when(request.close()).thenReturn(new Future<HttpClientResponse>
                       .value(response));
  when(response.contentLength).thenReturn(_kTransparentImageBytes.length);
  when(response.statusCode).thenReturn(HttpStatus.ok);
  when(response.listen(typed(any))).thenAnswer((Invocation invocation) {
    final void Function(List<int>) onData = invocation.positionalArguments[0];
    final void Function() onDone = invocation.namedArguments[#onDone];
    final void Function(Object, [StackTrace]) onError =
        invocation.namedArguments[#onError];
    final bool cancelOnError = invocation.namedArguments[#cancelOnError];
    return new Stream<List<int>>
        .fromIterable(<List<int>>[_kTransparentImageBytes])
        .listen(onData, onDone: onDone, onError: onError,
                cancelOnError: cancelOnError);
  });
  return client;
}

class MockHttpClient extends Mock implements HttpClient {}

class MockHttpClientRequest extends Mock implements HttpClientRequest {}

class MockHttpClientResponse extends Mock implements HttpClientResponse {}

class MockHttpHeaders extends Mock implements HttpHeaders {}
