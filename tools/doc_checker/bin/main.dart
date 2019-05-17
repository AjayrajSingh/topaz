// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as path;

import 'package:doc_checker/graph.dart';
import 'package:doc_checker/link_scraper.dart';
import 'package:doc_checker/link_verifier.dart';
import 'package:doc_checker/projects.dart';

const String _optionHelp = 'help';
const String _optionRootDir = 'root';
const String _optionProject = 'project';
const String _optionDotFile = 'dot-file';
const String _optionLocalLinksOnly = 'local-links-only';

// The fuchsia Gerrit host.
const String _fuchsiaHost = 'fuchsia.googlesource.com';

// Different ways of pointing to the master branch of a project in a Gerrit
// link.
const List<String> _masterSynonyms = ['master', 'refs/heads/master', 'HEAD'];

// Documentation subdirectory to inspect.
const String _docsDir = 'docs';

void reportError(Error error) {
  String errorToString(ErrorType type) {
    switch (type) {
      case ErrorType.unknownLocalFile:
        return 'Linking to unknown file';
      case ErrorType.convertHttpToPath:
        return 'Convert http to path';
      case ErrorType.brokenLink:
        return 'Http link is broken';
      case ErrorType.unreachablePage:
        return 'Page should be reachable';
      case ErrorType.obsoleteProject:
        return 'Project is obsolete';
      case ErrorType.invalidUri:
        return 'Invalid URI';
      default:
        throw UnsupportedError('Unknown error type $type');
    }
  }

  final String location = error.hasLocation ? ' (${error.location})' : '';
  print('${errorToString(error.type).padRight(25)}: ${error.content}$location');
}

enum ErrorType {
  unknownLocalFile,
  convertHttpToPath,
  brokenLink,
  unreachablePage,
  obsoleteProject,
  invalidUri,
}

class Error {
  final ErrorType type;
  final String location;
  final String content;

  Error(this.type, this.location, this.content);

  Error.forProject(this.type, this.content) : location = null;

  bool get hasLocation => location != null;
}

// Checks whether the URI points to the master branch of a Gerrit (i.e.,
// googlesource.com) project.
bool onGerritMaster(Uri uri) {
  final int index = uri.pathSegments.indexOf('+');
  if (index == -1 || index == uri.pathSegments.length - 1) {
    return false;
  }
  final String subPath = uri.pathSegments.sublist(index + 1).join('/');
  for (String branch in _masterSynonyms) {
    if (subPath.startsWith(branch)) {
      return true;
    }
  }
  return false;
}

Future<Null> main(List<String> args) async {
  final ArgParser parser = ArgParser()
    ..addFlag(
      _optionHelp,
      help: 'Displays this help message.',
      negatable: false,
    )
    ..addOption(
      _optionRootDir,
      help: 'Path to the root of the checkout',
      defaultsTo: '.',
    )
    ..addOption(
      _optionProject,
      help: 'Name of the project being inspected',
      defaultsTo: 'fuchsia',
    )
    ..addOption(
      _optionDotFile,
      help: 'Path to the dotfile to generate',
      defaultsTo: '',
    )
    ..addFlag(
      _optionLocalLinksOnly,
      help: 'Don\'t attempt to resolve http(s) links',
      negatable: false,
    );
  final ArgResults options = parser.parse(args);

  if (options[_optionHelp]) {
    print(parser.usage);
    return;
  }

  final String rootDir = path.canonicalize(options[_optionRootDir]);
  final String docsProject = options[_optionProject];
  final String docsDir = path.canonicalize(path.join(rootDir, _docsDir));

  final List<String> docs = Directory(docsDir)
      .listSync(recursive: true)
      .where((FileSystemEntity entity) =>
          path.extension(entity.path) == '.md' &&
          // Skip these files created by macOS since they're not real Markdown:
          // https://apple.stackexchange.com/q/14980
          !path.basename(entity.path).startsWith('._'))
      .map((FileSystemEntity entity) => entity.path)
      .toList();

  final String readme = path.join(docsDir, 'README.md');
  final Graph graph = Graph();
  final List<Error> errors = <Error>[];
  final List<Link<String>> inTreeLinks = [];
  final List<Link<String>> outOfTreeLinks = [];

  for (String doc in docs) {
    final String label = '//${path.relative(doc, from: rootDir)}';
    final String baseDir = path.dirname(doc);
    final Node node = graph.getNode(label);
    if (doc == readme) {
      graph.root = node;
    }
    for (String link in LinkScraper().scrape(doc)) {
      Uri uri;
      try {
        uri = Uri.parse(link);
      } on FormatException {
        errors.add(Error(ErrorType.invalidUri, label, link));
        continue;
      }

      if (uri.hasScheme) {
        if (uri.scheme != 'http' && uri.scheme != 'https') {
          continue;
        }
        final bool onFuchsiaHost  = uri.authority == _fuchsiaHost;
        final String project = uri.pathSegments.isEmpty? '' :
            uri.pathSegments[0];
        if (onFuchsiaHost && onGerritMaster(uri) && project == docsProject) {
          errors.add(Error(
              ErrorType.convertHttpToPath, label, uri.toString()));
        } else if (onFuchsiaHost && !validProjects.contains(project)) {
          errors.add(
              Error(ErrorType.obsoleteProject, label, uri.toString()));
        } else {
            outOfTreeLinks.add(Link(uri, label));
        }
        continue;
      }

      final List<String> parts = link.split('#');
      final String location = parts[0];
      if (location.isEmpty) {
        continue;
      }

      final String rootRelPath = location.startsWith('/') ?
          location.substring(1):
          path.relative(path.join(baseDir, location), from: rootDir);
      final String absPath = path.join(rootDir, rootRelPath);
      final String linkLabel = '//$rootRelPath';

      if (docs.contains(absPath)) {
        graph.addEdge(from: node, to: graph.getNode(linkLabel));
      }
      final Uri localUri = Uri.parse('file://$absPath');
      inTreeLinks.add(Link(localUri, label));
    }
  }

  // Verify http links pointing inside the tree just by checking to see if the
  // path exists, as HTTP calls would be unnecessarily expensive here.
  await Future.wait(inTreeLinks.map((Link<String> link) async {
    final File possibleFile = File.fromUri(link.uri);
    final Directory possibleDir = Directory.fromUri(link.uri);
    if (!possibleFile.existsSync() && !possibleDir.existsSync()) {
      errors.add(
          Error(ErrorType.brokenLink, link.payload, link.toString()));
    }
    return null;
  }));

  // Verify http links pointing outside the tree.
  if (!options[_optionLocalLinksOnly]) {
    await verifyLinks(outOfTreeLinks, (Link<String> link, bool isValid) {
      if (!isValid) {
        errors.add(
            Error(ErrorType.brokenLink, link.payload, link.uri.toString()));
      }
    });
  }

  // Verify singletons and orphans.
  final List<Node> unreachable = graph.removeSingletons()
    ..addAll(
        graph.orphans..removeWhere((Node node) => node.label == '//docs/navbar.md'));
  for (Node node in unreachable) {
    errors.add(Error.forProject(ErrorType.unreachablePage, node.label));
  }

  errors
    ..sort((Error a, Error b) => a.type.index - b.type.index)
    ..forEach(reportError);

  if (options[_optionDotFile].isNotEmpty) {
    graph.export('fuchsia_docs', File(options[_optionDotFile]).openWrite());
  }

  if (errors.isNotEmpty) {
    print('Found ${errors.length} error(s).');
    exitCode = 1;
  }
}
