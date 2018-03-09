// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show json;

import 'package:lib.daisy.fidl/daisy.fidl.dart';

/// Dart-idiomatic wrapper to create a modular.Daisy.
class DaisyBuilder {
  final Daisy _daisy;

  DaisyBuilder.verb(String verb)
      : _daisy = new Daisy(verb: verb, nouns: <NounEntry>[]);

  DaisyBuilder.url(String url)
      : _daisy = new Daisy(url: url, nouns: <NounEntry>[]);

  // Converts |value| to a JSON object and adds it to the Daisy. For typed
  // data, prefer to use addNounFromEntityReference().
  void addNoun<T>(String name, T value) {
    _addNoun(name, new Noun.withJson(json.encode(value)));
  }

  void addNounFromEntityReference(String name, String reference) {
    _addNoun(name, new Noun.withEntityReference(reference));
  }

  void addNounFromLink(String name, String linkName) {
    _addNoun(name, new Noun.withLinkName(linkName));
  }

  Daisy get daisy => _daisy;

  void _addNounFromNounEntry(NounEntry entry) {
    _daisy.nouns.add(entry);
  }

  void _addNoun(String name, Noun noun) {
    _addNounFromNounEntry(new NounEntry(name: name, noun: noun));
  }
}
