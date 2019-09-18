// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// On Fuchsia, in lieu of the ELF dynamic symbol table consumed through dladdr,
// the Dart VM profiler consumes symbols produced by this tool, which have the
// format
//
// struct {
//    uint32_t num_entries;
//    struct {
//      uint32_t offset;
//      uint32_t size;
//      uint32_t string_table_offset;
//    } entries[num_entries];
//    const char* string_table;
// }
//
// Entries are sorted by offset. String table entries are NUL-terminated.
//
// See also //third_party/dart/runtime/vm/native_symbol_fuchsia.cc

import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:args/args.dart";
import "package:path/path.dart" as path;

Future<void> main(List<String> args) async {
  final parser = new ArgParser();
  parser.addOption("build-id-dir", help: "Path to .build-id directory");
  parser.addOption("build-id-script", help: "Path to get_build_id.py script");
  parser.addOption("nm", help: "Path to `nm` tool");
  parser.addOption("binary",
      help: "Path to the ELF file to extract symbols from");
  parser.addOption("output", help: "Path to output symbol table");
  final usage = """
Usage: dart_profiler_symbols.dart [options]

Options:
${parser.usage};
""";

  String buildIdDir;
  String buildIdScript;
  String nm;
  String binary;
  String output;

  try {
    final options = parser.parse(args);
    buildIdDir = options["build-id-dir"];
    if (buildIdDir == null) {
      throw "Must specify --build-id-dir";
    }
    if (!FileSystemEntity.isDirectorySync(buildIdDir)) {
      throw "Cannot find $buildIdDir";
    }
    buildIdScript = options["build-id-script"];
    if (buildIdScript == null) {
      throw "Must specify --build-id-script";
    }
    if (!FileSystemEntity.isFileSync(buildIdScript)) {
      throw "Cannot find $buildIdScript";
    }
    nm = options["nm"];
    if (nm == null) {
      throw "Must specify --nm";
    }
    if (!FileSystemEntity.isFileSync(nm)) {
      throw "Cannot find $nm";
    }
    binary = options["binary"];
    if (binary == null) {
      throw "Must specify --binary";
    }
    if (!FileSystemEntity.isFileSync(binary)) {
      throw "Cannot find $binary";
    }
    output = options["output"];
    if (output == null) {
      throw "Must specify --output";
    }
  } catch (e) {
    print("ERROR: $e\n");
    print(usage);
    exitCode = 1;
    return;
  }

  await run(buildIdDir, buildIdScript, nm, binary, output);
}

class Symbol {
  int offset;
  int size;
  String name;
}

Future<void> run(String buildIdDir, String buildIdScript, String nm,
    String binary, String output) async {
  final buildIdResult =
      await Process.run(buildIdScript, ["--build-id", binary]);
  final buildId = buildIdResult.stdout.trim();

  var unstrippedFile = path.join(
      buildIdDir, buildId.substring(0, 2), buildId.substring(2) + ".debug");
  if (!FileSystemEntity.isFileSync(unstrippedFile)) {
    throw "Cannot find unstripped file for: $binary";
  }
  final args = ["--demangle", "--numeric-sort", "--print-size", unstrippedFile];
  final result = await Process.run(nm, args);
  if (result.exitCode != 0) {
    print(result.stdout);
    print(result.stderr);
    throw "Command failed: $nm $args";
  }

  var symbols = new List();

  var regex = new RegExp("([0-9A-Za-z]+) ([0-9A-Za-z]+) (t|T|w|W) (.*)");
  for (final line in result.stdout.split("\n")) {
    var match = regex.firstMatch(line);
    if (match == null) {
      continue; // Ignore non-text symbols.
    }

    final symbol = new Symbol();

    // Note that capture groups start at 1.
    symbol.offset = int.parse(match[1], radix: 16);
    symbol.size = int.parse(match[2], radix: 16);
    symbol.name = match[4].split("(")[0];

    if (symbol.name.startsWith("\$")) {
      continue; // Ignore compiler/assembler temps.
    }

    symbols.add(symbol);
  }

  if (symbols.isEmpty) {
    throw "$unstrippedFile has no symbols";
  }

  var nameTable = new BytesBuilder();
  var binarySearchTable = new Uint32List(symbols.length * 3 + 1);
  var binarySearchTableIndex = 0;
  binarySearchTable[binarySearchTableIndex++] = symbols.length;
  // Symbols are sorted by offset because of --numeric-sort.
  for (var symbol in symbols) {
    var nameOffset = nameTable.length;
    nameTable.add(utf8.encode(symbol.name));
    nameTable.addByte(0);
    binarySearchTable[binarySearchTableIndex++] = symbol.offset;
    binarySearchTable[binarySearchTableIndex++] = symbol.size;
    binarySearchTable[binarySearchTableIndex++] = nameOffset;
  }

  var file = new File(output);
  await file.parent.create(recursive: true);
  var sink = file.openWrite();
  sink.add(binarySearchTable.buffer.asUint8List());
  sink.add(nameTable.takeBytes());
  await sink.close();
}
