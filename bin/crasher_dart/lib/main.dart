// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

const _usage =
    'Dart app to simulate various crashes by throwing (async) exceptions '
    'or calling disallowed exit().\nUsage: dart crasher.dart [<async|sync|exit>]';

void main(List<String> args) {
  if (args.length > 1) {
    stderr.writeln(_usage);
    return;
  }

  if (args.isEmpty || args[0] == 'sync') {
    throwSync();
  } else if (args[0] == 'async') {
    throwAsync();
  } else if (args[0] == 'exit') {
    exit(1);
  } else {
    stderr.writeln(_usage);
    return;
  }
}

Future<void> throwAsync() async {
  Future.delayed(Duration(seconds: 1),
      () => throw Exception('Dart exception from async function'));
}

void throwSync() {
  throw Exception('Dart exception from sync function');
}
