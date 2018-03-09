// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:xi_client/client.dart';

/// [XiFlutterClient] constructor.
class XiFlutterClient extends XiClient {
  /// The xi-core process
  Process process;

  @override
  void send(String data) {
    if (!initialized) {
      throw new StateError('Must call .init() first.');
    }

    process.stdin.writeln(data);
  }

  @override
  Future<Null> init() async {
    // Guard for ensuring the following initialization code is only executed
    // once.
    if (initialized) {
      return;
    }

    // Copy the xi-core binary to tmp.
    Directory tmp = await getTemporaryDirectory();
    String filename = path.join(tmp.uri.path, 'xi-core');
    try {
      await new File('/data/local/tmp/xi-core').copy(filename);
    } on FileSystemException catch (e) {
      // Note: we'll get a "text file busy" error when doing a reload from
      // "flutter run", so best to log the error and go on. Might want to
      // make error catching more fine-grained here.
      print('Error copying file: $e');
    }

    // Make the xi-core copy executable and start it.
    await Process.run('chmod', <String>['+x', filename]);
    process = await Process.start(filename, <String>[]);

    // Transform the unstructured stderr from the xi-core process and print
    // it.
    process.stderr.transform(utf8.decoder).listen(
          (String data) => print('[xi-core stderr]: $data'),
          onError: onError,
          cancelOnError: true,
        );

    process.stdout.listen(streamController.add);
    initialized = true;
  }
}
