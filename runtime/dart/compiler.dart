// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';

import 'package:vm/kernel_front_end.dart'
    show createCompilerArgParser, runCompiler, successExitCode;

final ArgParser _argParser = createCompilerArgParser()
  ..addOption('component-name', help: 'Name of the component')
  ..addOption('data-dir',
      help: 'Name of the subdirectory of //data for output files')
  ..addOption('manifest', help: 'Path to output Fuchsia package manifest');

String _usage = '''
Usage: compiler [options] input.dart

Options:
${_argParser.usage}
''';

Future<void> main(List<String> args) async {
  ArgResults options;
  try {
    options = _argParser.parse(args);
    if (!options.rest.isNotEmpty) {
      throw new Exception('Must specify input.dart');
    }
  } on Exception catch (error) {
    print('ERROR: $error\n');
    print(_usage);
    exitCode = 1;
    return;
  }

  final compilerExitCode = await runCompiler(options, _usage);
  if (compilerExitCode != successExitCode) {
    exitCode = compilerExitCode;
    return;
  }

  final String output = options['output'];
  final String dataDir = options.options.contains('component-name')
      ? options['component-name']
      : options['data-dir'];
  final String manifestFilename = options['manifest'];

  if (manifestFilename != null) {
    await createManifest(manifestFilename, dataDir, output);
  }
}

Future createManifest(
    String packageManifestFilename, String dataDir, String output) async {
  List<String> packages = await new File('$output-packages').readAsLines();

  // Make sure the 'main' package is the last (convention with package loader).
  packages.remove('main');
  packages.add('main');

  final IOSink packageManifest = new File(packageManifestFilename).openWrite();
  final String kernelListFilename = '$packageManifestFilename.dilplist';
  final IOSink kernelList = new File(kernelListFilename).openWrite();

  for (String package in packages) {
    final String filenameInPackage = '$package.dilp';
    final String filenameInBuild = '$output-$package.dilp';
    packageManifest
        .write('data/$dataDir/$filenameInPackage=$filenameInBuild\n');
    kernelList.write('$filenameInPackage\n');
  }

  packageManifest.write('data/$dataDir/app.dilplist=$kernelListFilename\n');
  await packageManifest.close();
  await kernelList.close();
}
