// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:chat_conversation/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Conversation JSON', () {
    CommandMessage message = new CommandMessage(
      messageId: <int>[1, 2, 3],
      time: new DateTime.now(),
      sender: 'me',
      payload: '/mod hello world',
    );

    expect(message.command, equals(CommandType.mod));
    expect(message.arguments, equals(<String>['hello', 'world']));
  });
}
