// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Holds structured data decoded from the Entity's data.
class IntentEntityData {
  /// Create an [IntentEntityData] with a verb
  IntentEntityData.fromVerb(this.verb)
      : assert(verb.isNotEmpty),
        url = null;

  /// Create an [IntentEntityData] with a url
  IntentEntityData.fromUrl(this.url)
      : assert(url.isNotEmpty),
        verb = null;

  /// The verb of an Intent
  final String verb;

  /// The package name of the module
  final String url;

  /// The map of nouns names and their data (JSON object)
  final Map<String, String> nouns = <String, String>{};
}
