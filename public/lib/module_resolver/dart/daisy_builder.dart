// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JSON;

import 'package:lib.module_resolver.fidl/daisy.fidl.dart';

/// Dart-idiomatic wrapper to create a modular.Daisy.
class DaisyBuilder {
  final Daisy _daisy;

  DaisyBuilder.verb(String verb)
      : _daisy = new Daisy(verb: verb, nouns: <String, Noun>{});

  DaisyBuilder.url(String url)
      : _daisy = new Daisy(url: url, nouns: <String, Noun>{});

  // Converts |value| to a JSON object and adds it to the Daisy. For typed
  // data, prefer to use addNounFromEntityReference().
  void addNoun<T>(String name, T value) {
    _daisy.nouns[name] = new Noun.withJson(JSON.encode(value));
  }

  void addNounFromEntityReference(String name, String reference) {
    _daisy.nouns[name] = new Noun.withEntityReference(reference);
  }

  void addNounFromLink(String name, String linkName) {
    _daisy.nouns[name] = new Noun.withLinkName(linkName);
  }

  Daisy get daisy => _daisy;
}
