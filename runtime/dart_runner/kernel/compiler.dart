// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import 'package:front_end/src/api_prototype/byte_store.dart';
import 'package:front_end/src/api_prototype/compiler_options.dart';
import 'package:front_end/src/api_prototype/incremental_kernel_generator.dart';

import 'package:kernel/binary/limited_ast_to_binary.dart';
import 'package:kernel/target/targets.dart';

import 'package:vm/kernel_front_end.dart' show compileToKernel;
import 'package:vm/target/runner.dart';

ArgParser _argParser = new ArgParser(allowTrailingOptions: true)
  ..addOption('sdk-root',
      help: 'Path to runner_patched_sdk')
  ..addFlag('aot',
      help: 'Run compiler in AOT mode (enables whole-program transformations)',
      defaultsTo: false)
  ..addFlag('strong',
      help: 'Run compiler in strong mode (uses strong mode semantics)',
      defaultsTo: false)
  ..addFlag('embed-sources',
      help: 'Embed sources in the output dill file',
      defaultsTo: true)  // TODO(dartbug.com/32007): Default to false.
  ..addOption('packages',
      help: 'Path to .packages file')
  ..addOption('depfile',
      help: 'Path to output Ninja depfile')
  ..addOption('output',
      help: 'Path to output dill file');

String _usage = '''
Usage: compiler [options] [input.dart]

Options:
${_argParser.usage}
''';

Uri _ensureFolderPath(String path) {
  String uriPath = new Uri.file(path).toString();
  if (!uriPath.endsWith('/')) {
    uriPath = '$uriPath/';
  }
  return Uri.base.resolve(uriPath);
}

Future<void> main(List<String> args) async {
  ArgResults options;
  try {
    options = _argParser.parse(args);
    if (!options.rest.isNotEmpty) {
      throw "Must specify input.dart";
    }
  } catch (error) {
    print('ERROR: $error\n');
    print(_usage);
    exitCode = 1;
    return;
  }

  final Uri sdkRoot = _ensureFolderPath(options['sdk-root']);
  final String packages = options['packages'];
  final String depfile = options['depfile'];
  final String kernelBinaryFilename = options['output'];
  final bool strongMode = options['strong'];
  final bool aot = options['aot'];
  final bool embedSources = options['embed-sources'];

  final String filename = options.rest[0];
  final Uri filenameUri = Uri.base.resolveUri(new Uri.file(filename));

  final CompilerOptions compilerOptions = new CompilerOptions()
      ..byteStore = new MemoryByteStore()
      ..sdkRoot = sdkRoot
      ..strongMode = strongMode
      ..packagesFileUri = packages != null ? Uri.base.resolve(packages) : null
      ..target = new RunnerTarget(new TargetFlags(strongMode: strongMode))
      ..embedSourceText = embedSources
      ..reportMessages = true;

  Program program;
  if (!aot) {
    IncrementalKernelGenerator generator =
        new IncrementalKernelGenerator(compilerOptions, filenameUri);
    program = await generator.computeDelta();
  } else {
    throw "Unimplemented";
    // program = await compileToKernel(filenameUri, compilerOptions, aot: true);
  }

  final IOSink sink = new File(kernelBinaryFilename).openWrite();
  final BinaryPrinter printer =
      new LimitedBinaryPrinter(sink, (_) => true /* predicate */,
                               false /* excludeUriToSource */);
  printer.writeProgramFile(program);
  await sink.close();

  if (depfile != null) {
    await writeDepfile(program, kernelBinaryFilename, depfile);
  }
}

String escapePath(String path) {
  return path.replaceAll(r'\', r'\\').replaceAll(r' ', r'\ ');
}

// https://ninja-build.org/manual.html#_depfile
Future<void> writeDepfile(Program program, String output, String depfile) async {
  var deps = new List<Uri>();
  for (Library lib in program.libraries) {
    deps.add(lib.fileUri);
    for (LibraryPart part in lib.parts) {
      deps.add(part.fileUri);
    }
  }

  var file = new File(depfile).openWrite();
  file.write(escapePath(output));
  file.write(':');
  for (Uri dep in deps) {
    file.write(' ');
    file.write(escapePath(dep.toFilePath()));
  }
  file.write('\n');
  await file.close();
}
