// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show base64;
import 'dart:io';

// ignore_for_file: public_member_api_docs

/// A BASE64 encoded 1x1 transparent PNG image.
final List<int> _kTransparentImageBytes = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

/// Returns a fake HTTP client that responds with an image to all requests.
FakeHttpClient createFakeImageHttpClient(SecurityContext _) {
  return FakeHttpClient();
}

class FakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    return Future.value(FakeHttpClientRequest());
  }

  @override
  void noSuchMethod(Invocation invocation) {
    // noSuchMethod is that 'magic' that allows us to ignore implementing fields
    // and methods and instead define them later at compile-time per instance.
    // See "Emulating Functions and Interactions" on dartlang.org: goo.gl/r3IQUH
  }
}

class FakeHttpClientRequest implements HttpClientRequest {
  @override
  HttpHeaders get headers {
    return FakeHttpHeaders();
  }

  @override
  Future<HttpClientResponse> close() {
    return Future.value(FakeHttpClientResponse());
  }

  @override
  void noSuchMethod(Invocation invocation) {
    // noSuchMethod is that 'magic' that allows us to ignore implementing fields
    // and methods and instead define them later at compile-time per instance.
    // See "Emulating Functions and Interactions" on dartlang.org: goo.gl/r3IQUH
  }
}

class FakeHttpClientResponse implements HttpClientResponse {
  @override
  int get contentLength {
    return _kTransparentImageBytes.length;
  }

  @override
  int get statusCode {
    return HttpStatus.ok;
  }

  @override
  StreamSubscription<List<int>> listen(void onData(List<int> event),
      {Function onError, void onDone(), bool cancelOnError}) {
    return Stream<List<int>>.fromIterable(
            <List<int>>[_kTransparentImageBytes])
        .listen(onData,
            onDone: onDone, onError: onError, cancelOnError: cancelOnError);
  }

  // Some libraries, including flutter_image, make use of this method.
  @override
  Future<S> fold<S>(S initialValue, S combine(S previous, List<int> element)) {
    return Future.value(combine(initialValue, _kTransparentImageBytes));
  }

  @override
  void noSuchMethod(Invocation invocation) {
    // noSuchMethod is that 'magic' that allows us to ignore implementing fields
    // and methods and instead define them later at compile-time per instance.
    // See "Emulating Functions and Interactions" on dartlang.org: goo.gl/r3IQUH
  }
}

class FakeHttpHeaders implements HttpHeaders {
  @override
  void noSuchMethod(Invocation invocation) {
    // noSuchMethod is that 'magic' that allows us to ignore implementing fields
    // and methods and instead define them later at compile-time per instance.
    // See "Emulating Functions and Interactions" on dartlang.org: goo.gl/r3IQUH
  }
}
