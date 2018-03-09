// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show base64;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http;

/// A BASE64 encoded 1x1 transparent PNG image.
final List<int> _kTransparentImageBytes = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

/// Creates a new [http.MockClient] that returns a mock image.
///
/// The intended usage in test is:
///
///     import 'package:flutter/services.dart';
///     import 'package:lib.testing/flutter/testing.dart';
///
///     // At the beginning of your test, add the following line.
///     createHttpClient = createMockImageHttpClient;
http.Client createMockImageHttpClient() {
  return new http.MockClient((http.Request request) async {
    return new http.Response.bytes(
      _kTransparentImageBytes,
      200,
      request: request,
    );
  });
}
