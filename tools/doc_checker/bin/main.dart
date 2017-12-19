// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'package:doc_checker/graph.dart';
import 'package:doc_checker/link_scraper.dart';

const String _optionHelp = 'help';
const String _optionRootDir = 'root-dir';
const String _optionDotFile = 'dot-file';
const String _optionGitProject = 'git-project';

void reportError(String type, String value) {
  print('${type.padRight(25)}: $value');
}

void main(List<String> args) {
  final ArgParser parser = new ArgParser()
    ..addFlag(
      _optionHelp,
      help: 'Displays this help message.',
      negatable: false,
    )
    ..addOption(
      _optionRootDir,
      help: 'Path to the directory to inspect',
      defaultsTo: 'docs',
    )
    ..addOption(
      _optionDotFile,
      help: 'Path to the dotfile to generate',
      defaultsTo: 'graph.dot',
    )
    ..addOption(
      _optionGitProject,
      help: 'Name of the Git project hosting the documentation directory',
      defaultsTo: 'docs',
    );
  final ArgResults options = parser.parse(args);

  if (options[_optionHelp]) {
    print(parser.usage);
    return;
  }

  final String docsDir = path.canonicalize(options[_optionRootDir]);

  final List<String> docs = new Directory(docsDir)
      .listSync(recursive: true)
      .where((FileSystemEntity entity) => path.extension(entity.path) == '.md')
      .map((FileSystemEntity entity) => entity.path);

  final String readme = path.join(docsDir, 'README.md');
  final Graph graph = new Graph();
  final List<Uri> httpLinks = <Uri>[];
  final List<String> relativeExternalLinks = <String>[];
  final List<String> missingLocal = <String>[];

  for (String doc in docs) {
    final String label = path.relative(doc, from: docsDir);
    final String baseDir = path.dirname(doc);
    final Node node = graph.getNode(label);
    if (doc == readme) {
      graph.root = node;
    }
    for (String link in new LinkScraper().scrape(doc)) {
      final Uri uri = Uri.parse(link);
      if (uri.hasScheme) {
        if (uri.scheme == 'http' || uri.scheme == 'https') {
          httpLinks.add(uri);
        }
        continue;
      }
      final List<String> parts = link.split('#');
      final String location =
          parts[0].startsWith('/') ? parts[0].substring(1) : parts[0];
      if (location.isEmpty) {
        continue;
      }
      final String absoluteLocation =
          path.canonicalize(path.join(baseDir, location));
      if (path.isWithin(docsDir, absoluteLocation)) {
        final String relativeLocation =
            path.relative(absoluteLocation, from: docsDir);
        if (docs.contains(absoluteLocation)) {
          graph.addEdge(from: node, to: graph.getNode(relativeLocation));
        } else {
          missingLocal.add(relativeLocation);
        }
      } else {
        relativeExternalLinks.add(location);
      }
    }
  }

  bool hasStructureError = false;

  // Verify that relative paths are within the directory.
  hasStructureError = hasStructureError || relativeExternalLinks.isNotEmpty;
  for (String location in relativeExternalLinks) {
    reportError('Convert path to http', location);
  }

  // Verify that all local links work.
  hasStructureError = hasStructureError || missingLocal.isNotEmpty;
  for (String location in missingLocal) {
    reportError('Linking to unknown file', location);
  }

  // Verify that HTTP links do not point to the same project.
  final List<Uri> localLinks = httpLinks
      .where((Uri uri) =>
          uri.authority == 'fuchsia.googlesource.com' &&
          uri.pathSegments.isNotEmpty &&
          uri.pathSegments[0] == options[_optionGitProject])
      .toList();
  hasStructureError = hasStructureError || localLinks.isNotEmpty;
  for (Uri uri in localLinks) {
    reportError('Convert http to path', uri.toString());
  }

  // Verify that HTTP links point to valid locations.
  Future
      .wait(httpLinks.map((Uri uri) async =>
          (await http.get(uri)).statusCode == 200 ? null : uri))
      .then((List<Uri> uris) {
    final List<Uri> errors = uris.where((Uri uri) => uri != null);
    hasStructureError = hasStructureError || errors.isNotEmpty;
    for (Uri uri in errors) {
      reportError('Http link is broken', uri.toString());
    }
  });

  // Verify singletons and orphans.
  final List<Node> unreachable = graph.removeSingletons()
    ..addAll(
        graph.orphans..removeWhere((Node node) => node.label == 'navbar.md'));
  hasStructureError = hasStructureError || unreachable.isNotEmpty;
  for (Node node in unreachable) {
    reportError('Page should be reachable', node.label);
  }

  graph.export('fuchsia_docs', new File(options[_optionDotFile]).openWrite());

  exitCode = hasStructureError ? 1 : 0;
}
