// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as path;

import 'package:doc_checker/graph.dart';
import 'package:doc_checker/link_scraper.dart';

const String _optionFuchsiaDir = 'fuchsia-dir';
const String _optionDotFile = 'dot-file';

/// Returns the label of the given link, or `null` if the link should not be
/// represented by a node.
String labelForLink(String link) {
  final Uri uri = Uri.parse(link);
  if (uri.scheme.isNotEmpty) {
    return null;
  }
  // TODO(pylaligand): deal with '..' in paths.
  final List<String> parts = link.split('#');
  return parts[0].isNotEmpty ? parts[0] : null;
}

void main(List<String> args) {
  final ArgParser parser = new ArgParser()
    ..addOption(
      _optionFuchsiaDir,
      help: 'Path to the root of the Fuchsia tree',
      defaultsTo: '.',
    )
    ..addOption(
      _optionDotFile,
      help: 'Path to the dotfile to generate',
      defaultsTo: 'graph.dot',
    );
  final ArgResults options = parser.parse(args);

  final String fuchsiaDir = path.canonicalize(options[_optionFuchsiaDir]);
  final String docsDir = path.join(fuchsiaDir, 'docs');

  final List<String> docs = new Directory(docsDir)
      .listSync(recursive: true)
      .where((FileSystemEntity entity) => path.extension(entity.path) == '.md')
      .map((FileSystemEntity entity) => entity.path);

  final String readme = path.join(docsDir, 'README.md');
  final Graph graph = new Graph();

  for (String doc in docs) {
    final String label = path.relative(doc, from: docsDir);
    final Node node = graph.getNode(label);
    if (doc == readme) {
      graph.root = node;
    }
    for (String link in new LinkScraper().scrape(doc)) {
      final String label = labelForLink(link);
      if (label != null) {
        graph.addEdge(from: node, to: graph.getNode(label));
      }
    }
  }

  graph.export('fuchsia_docs', new File(options[_optionDotFile]).openWrite());
}
