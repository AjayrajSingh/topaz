// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';

import 'package:front_end/src/api_prototype/compiler_options.dart';

import 'package:kernel/ast.dart';
import 'package:kernel/binary/ast_to_binary.dart';
import 'package:kernel/binary/limited_ast_to_binary.dart';
import 'package:kernel/target/targets.dart';

import 'package:vm/kernel_front_end.dart' show compileToKernel;
import 'package:vm/target/dart_runner.dart' show DartRunnerTarget;
import 'package:vm/target/flutter_runner.dart' show FlutterRunnerTarget;

ArgParser _argParser = new ArgParser(allowTrailingOptions: true)
  ..addOption('sdk-root', help: 'Path to runner_patched_sdk')
  ..addFlag('aot',
      help: 'Run compiler in AOT mode (enables whole-program transformations)',
      defaultsTo: false)
  ..addFlag('embed-sources',
      help: 'Embed sources in the output dill file', defaultsTo: false)
  ..addOption('target', help: 'Kernel target name')
  ..addOption('packages', help: 'Path to .packages file')
  ..addOption('depfile', help: 'Path to output Ninja depfile')
  ..addOption('manifest', help: 'Path to output Fuchsia package manifest')
  ..addOption('output', help: 'Path to output dill file');

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
  }

  final Uri sdkRoot = _ensureFolderPath(options['sdk-root']);
  final String packages = options['packages'];
  final String depfile = options['depfile'];
  final String kernelBinaryFilename = options['output'];
  final bool aot = options['aot'];
  final bool embedSources = options['embed-sources'];
  final String targetName = options['target'];

  final String filename = options.rest[0];
  final Uri filenameUri = Uri.base.resolveUri(new Uri.file(filename));

  Uri platformKernelDill = sdkRoot.resolve('platform_strong.dill');

  TargetFlags targetFlags = new TargetFlags(strongMode: true, syncAsync: true);
  Target target;
  switch (targetName) {
    case 'dart_runner':
      target = new DartRunnerTarget(targetFlags);
      break;
    case 'flutter_runner':
      target = new FlutterRunnerTarget(targetFlags);
      break;
    default:
      print("Unknown target: $targetName");
      exitCode = 1;
      return;
  }

  final CompilerOptions compilerOptions = new CompilerOptions()
    ..sdkSummary = platformKernelDill
    ..strongMode = true
    ..packagesFileUri = packages != null ? Uri.base.resolve(packages) : null
    ..target = target
    ..embedSourceText = embedSources
    ..reportMessages = true
    ..setExitCodeOnProblem = true;

  if (aot) {
    // Link in the platform to produce an output with no external references.
    compilerOptions.linkedDependencies = <Uri>[
      platformKernelDill
    ];
  }

  Component program =
      await compileToKernel(filenameUri, compilerOptions, aot: aot);

  final IOSink sink = new File(kernelBinaryFilename).openWrite();
  final BinaryPrinter printer = new LimitedBinaryPrinter(sink,
      (Library lib) => aot || !lib.isExternal, false /* excludeUriToSource */);
  printer.writeComponentFile(program);
  await sink.close();

  if (depfile != null) {
    await writeDepfile(program, kernelBinaryFilename, depfile);
  }

  final String manifestFilename = options['manifest'];
  if (manifestFilename != null) {
    await writePackages(program, kernelBinaryFilename, manifestFilename);
  }
}

String escapePath(String path) {
  return path.replaceAll('\\', '\\\\').replaceAll(' ', '\\ ');
}

// https://ninja-build.org/manual.html#_depfile
Future<void> writeDepfile(
    Program program, String output, String depfile) async {
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

Future writePackages(Component program, String output, String packageManifestFilename) async {
  // Package sharing: make the encoding not depend on the order in which parts
  // of a package are loaded.
  program.libraries.sort((Library a, Library b) {
    return a.importUri.toString().compareTo(b.importUri.toString());
  });
  for (Library lib in program.libraries) {
    lib.additionalExports.sort((Reference a, Reference b) {
      return a.canonicalName.toString().compareTo(b.canonicalName.toString());
    });
  }

  final IOSink packageManifest = new File(packageManifestFilename).openWrite();
  final String loadManifestFilename = packageManifestFilename+"-load";
  final IOSink loadManifest = new File(loadManifestFilename).openWrite();

  final packages = new Set<String>();
  for (Library lib in program.libraries) {
    packages.add(packageFor(lib));
  }
  packages.remove("main");
  packages.remove(null);

  for (String package in packages) {
    await writePackage(program, output, package, packageManifest, loadManifest);
  }
  await writePackage(program, output, "main", packageManifest, loadManifest);

  packageManifest.write("manifest=$loadManifestFilename\n");
  await packageManifest.close();
  await loadManifest.close();
}

Future writePackage(Component program, String output, String package,
                    IOSink packageManifest, IOSink loadManifest) async {
  final String filenameInPackage = package + ".dilp";
  final String filenameInBuild = output + "-" + package + ".dilp";
  final IOSink sink = new File(filenameInBuild).openWrite();

  var main = program.mainMethod;
  if (package != "main") {
    // Package sharing: remove the information about the importer from package
    // dilps.
    program.mainMethod = null;
  }
  final BinaryPrinter printer =
      new LimitedBinaryPrinter(sink, (lib) => packageFor(lib) == package,
                               false /* excludeUriToSource */);
  printer.writeComponentFile(program);
  program.mainMethod = main;

  await sink.close();

  packageManifest.write("$filenameInPackage=$filenameInBuild\n");
  loadManifest.write("$filenameInPackage\n");
}

String packageFor(Library lib) {
  // Core libraries are not written into any dilp.
  if (lib.isExternal)
    return null;

  // Packages are written into their own dilp.
  Uri uri = lib.importUri;
  if (uri.scheme == "package")
    return uri.pathSegments.first;

  // Everything else (e.g., file: or data: imports) is lumped into the main dilp.
  return "main";
}
