// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';

import 'package:front_end/src/api_unstable/vm.dart';
import 'package:front_end/src/scheme_based_file_system.dart'
    show SchemeBasedFileSystem;

import 'package:build_integration/file_system/single_root.dart'
    show SingleRootFileSystem, SingleRootFileSystemEntity;

import 'package:kernel/ast.dart';
import 'package:kernel/binary/ast_to_binary.dart';
import 'package:kernel/binary/limited_ast_to_binary.dart';
import 'package:kernel/target/targets.dart';

import 'package:vm/kernel_front_end.dart'
    show compileToKernel, ErrorDetector, ErrorPrinter;
import 'package:vm/target/dart_runner.dart' show DartRunnerTarget;
import 'package:vm/target/flutter_runner.dart' show FlutterRunnerTarget;

ArgParser _argParser = new ArgParser(allowTrailingOptions: true)
  ..addOption('sdk-root', help: 'Path to runner_patched_sdk')
  ..addOption('single-root-scheme', help: 'The URI scheme for the single root')
  ..addOption('single-root-base', help: 'The base for the single root')
  ..addFlag('aot',
      help: 'Run compiler in AOT mode (enables whole-program transformations)',
      defaultsTo: false)
  ..addFlag('tfa',
      help: 'Run global type flow analysis', defaultsTo: false)
  ..addFlag('drop-ast',
      help: 'Drop AST for members with bytecode', defaultsTo: false)
  ..addOption('component-name', help: 'Name of the component')
  ..addFlag('embed-sources',
      help: 'Embed sources in the output dill file', defaultsTo: false)
  ..addFlag('gen-bytecode', help: 'Generate bytecode', defaultsTo: false)
  ..addOption('depfile', help: 'Path to output Ninja depfile')
  ..addOption('manifest', help: 'Path to output Fuchsia package manifest')
  ..addOption('output', help: 'Path to output dill file')
  ..addOption('packages', help: 'Path to .packages file')
  ..addOption('target', help: 'Kernel target name')
  ..addFlag('verbose', help: 'Run in verbose mode');

String _usage = '''
Usage: compiler [options] input.dart

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
      throw new Exception('Must specify input.dart');
    }
  } on Exception catch (error) {
    print('ERROR: $error\n');
    print(_usage);
    exitCode = 1;
    return;
  }

  final Uri sdkRoot = _ensureFolderPath(options['sdk-root']);
  final String singleRootScheme = options['single-root-scheme'];
  final Uri singleRootBase = new Uri.file(options['single-root-base']);
  final Uri packagesUri = Uri.base.resolve(options['packages']);
  final bool aot = options['aot'];
  final bool tfa = options['tfa'];
  final bool embedSources = options['embed-sources'];
  final String targetName = options['target'];
  final bool genBytecode = options['gen-bytecode'];
  final bool dropAST = options['drop-ast'];
  final String componentName = options['component-name'];
  final bool verbose = options['verbose'];

  Uri mainUri = Uri.parse(options.rest[0]);

  Uri platformKernelDill = sdkRoot.resolve('platform_strong.dill');

  TargetFlags targetFlags = new TargetFlags(syncAsync: true);
  Target target;
  switch (targetName) {
    case 'dart_runner':
      target = new DartRunnerTarget(targetFlags);
      break;
    case 'flutter_runner':
      target = new FlutterRunnerTarget(targetFlags);
      break;
    default:
      print('Unknown target: $targetName');
      exitCode = 1;
      return;
  }

  FileSystem fileSystem = StandardFileSystem.instance;
  if (singleRootScheme != null) {
    SingleRootFileSystem singleRootFS =
        new SingleRootFileSystem(singleRootScheme, singleRootBase, fileSystem);
    fileSystem = new SchemeBasedFileSystem({
      'file': fileSystem,
      'data': fileSystem,
      '': fileSystem,
      singleRootScheme: singleRootFS,
    });
  }

  // fuchsia-source:///x/y/main.dart -> file:///a/b/x/y/main.dart
  String mainUriString;
  if (mainUri.scheme == singleRootScheme) {
    String mainPath = mainUri.path;
    if (mainPath.startsWith('/')) {
      mainPath = mainPath.substring(1);
    }
    mainUriString = singleRootBase.resolve(mainPath).toString();
  } else {
    mainUriString = mainUri.toString();
  }
  // file:///a/b/x/y/main.dart -> package:x.y/main.dart
  for (var line in await new File(packagesUri.toFilePath()).readAsLines()) {
    var colon = line.indexOf(':');
    if (colon == -1)
      continue;
    var packageName = line.substring(0, colon);
    var packagePath = line.substring(colon + 1);
    if (mainUriString.startsWith(packagePath)) {
      mainUri = Uri.parse('package:$packageName/${mainUriString.substring(packagePath.length)}');
      break;
    }
  }

  final errorPrinter = new ErrorPrinter();
  final errorDetector = new ErrorDetector(previousErrorHandler: errorPrinter);
  final CompilerOptions compilerOptions = new CompilerOptions()
    ..sdkSummary = platformKernelDill
    ..fileSystem = fileSystem
    ..packagesFileUri = packagesUri
    ..target = target
    ..embedSourceText = embedSources
    ..onDiagnostic = (DiagnosticMessage m) {
      printDiagnosticMessage(m, stderr.writeln);
      errorDetector(m);
    }
    ..verbose = verbose;

  if (aot) {
    // Link in the platform to produce an output with no external references.
    compilerOptions.linkedDependencies = <Uri>[platformKernelDill];
  }

  Component component = await compileToKernel(
    mainUri,
    compilerOptions,
    aot: aot,
    useGlobalTypeFlowAnalysis: tfa,
    genBytecode: genBytecode,
    dropAST: dropAST,
  );

  errorPrinter.printCompilationMessages(mainUri);
  if (errorDetector.hasCompilationErrors || (component == null)) {
    exitCode = 1;
    return;
  }

  // Single-file output.
  final String kernelBinaryFilename = options['output'];
  if (kernelBinaryFilename != null) {
    final IOSink sink = new File(kernelBinaryFilename).openWrite();
    final BinaryPrinter printer = new LimitedBinaryPrinter(sink,
        (Library lib) => true, false /* excludeUriToSource */);
    printer.writeComponentFile(component);
    await sink.close();

    final String depfile = options['depfile'];
    if (depfile != null) {
      await writeDepfile(fileSystem, component, kernelBinaryFilename, depfile);
    }
  }

  // Multiple-file output.
  final String manifestFilename = options['manifest'];
  if (manifestFilename != null) {
    await writePackages(component, kernelBinaryFilename, manifestFilename, componentName);
  }
}

String escapePath(String path) {
  return path.replaceAll('\\', '\\\\').replaceAll(' ', '\\ ');
}

List<Uri> getDependencies(Component component) {
  var deps = <Uri>[];
  for (Library lib in component.libraries) {
    if (lib.importUri.scheme == 'dart') {
      continue;
    }
    deps.add(lib.fileUri);
    for (LibraryPart part in lib.parts) {
      final Uri fileUri = lib.fileUri.resolve(part.partUri);
      deps.add(fileUri);
    }
  }
  return deps;
}

// https://ninja-build.org/manual.html#_depfile
Future<void> writeDepfile(FileSystem fileSystem,
    Component component, String output, String depfile) async {
  var file = new File(depfile).openWrite();
  file.write(escapePath(output));
  file.write(':');
  for (Uri dep in getDependencies(component)) {
    FileSystemEntity fse = fileSystem.entityForUri(dep);
    if (fse is SingleRootFileSystemEntity) {
      SingleRootFileSystemEntity srfse = fse;
      fse = srfse.delegate;
    }
    Uri uri = fse.uri;
    file.write(' ');
    file.write(escapePath(uri.toFilePath()));
  }
  file.write('\n');
  await file.close();
}

Future writePackages(Component component, String output, String packageManifestFilename, String componentName) async {
  // Package sharing: make the encoding not depend on the order in which parts
  // of a package are loaded.
  component.libraries.sort((Library a, Library b) {
    return a.importUri.toString().compareTo(b.importUri.toString());
  });
  for (Library lib in component.libraries) {
    lib.additionalExports.sort((Reference a, Reference b) {
      return a.canonicalName.toString().compareTo(b.canonicalName.toString());
    });
  }

  final IOSink packageManifest = new File(packageManifestFilename).openWrite();
  final String kernelListFilename = '$packageManifestFilename.dilplist';
  final IOSink kernelList = new File(kernelListFilename).openWrite();

  final packages = new Set<String>();
  for (Library lib in component.libraries) {
    packages.add(packageFor(lib));
  }
  packages.remove('main');
  packages.remove(null);

  for (String package in packages) {
    await writePackage(component, output, package, packageManifest, kernelList, componentName);
  }
  await writePackage(component, output, 'main', packageManifest, kernelList, componentName);

  packageManifest.write('data/$componentName/app.dilplist=$kernelListFilename\n');
  await packageManifest.close();
  await kernelList.close();
}

Future writePackage(Component component, String output, String package,
    IOSink packageManifest, IOSink kernelList, String componentName) async {
  final String filenameInPackage = '$package.dilp';
  final String filenameInBuild = '$output-$package.dilp';
  final IOSink sink = new File(filenameInBuild).openWrite();

  var main = component.mainMethod;
  if (package != 'main') {
    // Package sharing: remove the information about the importer from package
    // dilps.
    component.mainMethod = null;
  }
  final BinaryPrinter printer = new LimitedBinaryPrinter(sink,
      (lib) => packageFor(lib) == package, false /* excludeUriToSource */);
  printer.writeComponentFile(component);
  component.mainMethod = main;

  await sink.close();

  packageManifest.write('data/$componentName/$filenameInPackage=$filenameInBuild\n');
  kernelList.write('$filenameInPackage\n');
}

String packageFor(Library lib) {
  // Core libraries are not written into any dilp.
  if (lib.isExternal)
    return null;

  // Packages are written into their own dilp.
  Uri uri = lib.importUri;
  if (uri.scheme == 'package')
    return uri.pathSegments.first;

  // Everything else (e.g., file: or data: imports) is lumped into the main dilp.
  return 'main';
}
