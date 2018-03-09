// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:chat_conversation_list/models.dart';
import 'package:test/test.dart';

void main() {
  test('User JSON encode/decode', () {
    User user = new User.fixture();

    String encoded = json.encode(user);
    Map<String, String> decoded = json.decode(encoded);
    User hydrated = new User.fromJson(decoded);

    expect(hydrated.id, equals(user.id));
    expect(hydrated.email, equals(user.email));
    expect(hydrated.name, equals(user.name));
    expect(hydrated.picture, equals(user.picture));
  });
}
