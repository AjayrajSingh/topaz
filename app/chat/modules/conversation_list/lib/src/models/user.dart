// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fixtures/fixtures.dart';
import 'package:widget_explorer_meta/widgets_meta.dart';

/// Represents a Google User Account
/// Fields are based off the data from the Google Identity API:
/// https://developers.google.com/identity/
@Generator(Fixtures, 'user')
class User {
  static final Fixtures _fixtures = new Fixtures();

  final List<String> _requiredKeys = <String>[
    'email',
  ];

  final Map<String, String> _json = <String, String>{
    'id': null,
    'email': null,
    'name': null,
    'givenName': null,
    'familyName': null,
    'picture': null,
    'locale': null,
  };

  /// Constructor to create a new user
  User();

  /// Construct a new User from JSON.
  User.fromJson(Map<String, String> json)
      : assert(json is Map && json != null) {
    for (String key in _requiredKeys) {
      assert(json[key] != null, 'JSON key "$key" is required');
    }

    json.forEach((String key, String value) {
      if (_json.containsKey(key)) {
        _json[key] = value;
      } else {
        String message = 'Invalid key "$key"';
        throw new FormatException(message);
      }
    });
  }

  /// Generate a new, random user (for tests).
  /// Generate a [User].
  ///
  /// Generate a random [User]:
  ///
  ///     User user = fixtures.user();
  ///
  /// Generate a [User] with a specific name:
  ///
  ///     User user = fixtures.user(name: 'Alice');
  ///
  factory User.fixture({
    String name,
    String email,
  }) {
    name ??= _fixtures.name(name);
    email ??= _fixtures.email();

    Map<String, String> json = <String, String>{
      'id': _fixtures.id('user'),
      'name': name,
      'email': email,
      'locale': 'en',
    };

    return new User.fromJson(json);
  }

  /// Unique ID for user
  String get id => _json['id'];

  /// Email address for user
  String get email => _json['email'];

  /// Full name for user, Ex: John Doe
  String get name => _json['name'] ?? _json['email'];

  /// URL for user avatar
  String get picture => _json['picture'];

  /// Helper function for JSON.encode() creates JSON-encoded User object.
  Map<String, dynamic> toJson() {
    return _json;
  }
}
