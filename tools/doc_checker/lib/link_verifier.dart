// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

class Link<P> {
  final Uri uri;
  final P payload;

  Link(this.uri, this.payload);

  @override
  String toString() => uri.toString();
}

typedef OnElementVerified<P> = void Function(Link<P> link, bool isValid);

Future<Null> verifyLinks<P>(
    List<Link<P>> links, OnElementVerified<P> callback) async {
  final Map<String, List<Link<P>>> urisByDomain = {};
  // Group URLs by domain in order to handle "too many requests" error on a
  // per-domain basis.
  for (Link<P> link in links) {
    urisByDomain.putIfAbsent(link.uri.authority, () => []).add(link);
  }
  await Future.wait(urisByDomain.keys.map((String domain) =>
      new _LinkVerifier(urisByDomain[domain]).verify(callback)));
  return null;
}

class _LinkVerifier<P> {
  final List<Link<P>> links;

  _LinkVerifier(this.links);

  Future<Null> verify(OnElementVerified<P> callback) async {
    for (Link<P> link in links) {
      callback(link, await _verifyLink(link));
    }
    return null;
  }

  Future<bool> _verifyLink(Link<P> link) async {
    try {
      for (int i = 0; i < 3; i++) {
        final http.Response response = await http.get(link.uri);
        final int code = response.statusCode;
        if (code == HttpStatus.tooManyRequests) {
          final int delay =
              int.tryParse(response.headers['retry-after'] ?? '') ?? 50;
          sleep(new Duration(milliseconds: delay));
          continue;
        }
        return code == HttpStatus.ok;
      }
    } on IOException {
      // Properly return an invalid link below instead of crashing.
    }
    return false;
  }
}
