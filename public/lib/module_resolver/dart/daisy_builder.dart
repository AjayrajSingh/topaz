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

  void addNoun<T>(String name, T value) {
    // We can accept various types of objects here (eventually Entity
    // handles, or Entity references or an EntityClient wrapper).
    // For now, assume everything should just be converted into JSON.
    _daisy.nouns[name] = new Noun.withJson(JSON.encode(value));
  }

  Daisy get daisy => _daisy;
}
