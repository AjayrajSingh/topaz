// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.widgets/modular.dart';

import 'src/modular/module_model.dart';

const double _kJsonViewerElevation = 1.0;
const double _kJsonViewerBorderRadius = 8.0;
const double _kJsonViewerListViewInset = 16.0;
const double _kJsonViewerEntryIndentPerLevel = 32.0;

const String _kListEntryPrefix = '\u{2022}'; // Unicode bullet point.

/// Main entry point to the link_viewer module.
void main() {
  setupLogger();

  ModuleWidget<LinkViewerModuleModel> moduleWidget =
      new ModuleWidget<LinkViewerModuleModel>(
    applicationContext: new ApplicationContext.fromStartupInfo(),
    moduleModel: new LinkViewerModuleModel(),
    child: new Center(
      child: new PhysicalModel(
        color: Colors.black,
        elevation: _kJsonViewerElevation,
        borderRadius: new BorderRadius.circular(_kJsonViewerBorderRadius),
        child: new _JsonViewer(),
      ),
    ),
  )..advertise();

  runApp(moduleWidget);
}

class _JsonViewer extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      new ScopedModelDescendant<LinkViewerModuleModel>(
        builder: (_, __, LinkViewerModuleModel model) {
          List<_Entry> entries = <_Entry>[];
          _addEntries(0, model.decodedJson, entries);
          if (entries.length > 20) {
            return new ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(_kJsonViewerListViewInset),
              physics: const BouncingScrollPhysics(),
              children: entries,
            );
          } else {
            return new SingleChildScrollView(
              padding: const EdgeInsets.all(_kJsonViewerListViewInset),
              physics: const BouncingScrollPhysics(),
              child: new Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: entries,
              ),
            );
          }
        },
      );

  void _addEntries(
    int indentLevel,
    Object decodedJson,
    List<_Entry> entries,
  ) {
    if (decodedJson is List) {
      for (int i = 0; i < decodedJson.length; i++) {
        if (decodedJson[i] is List || decodedJson[i] is Map) {
          entries.add(
            new _Entry(indentLevel: indentLevel, prefix: _kListEntryPrefix),
          );
          _addEntries(indentLevel + 1, decodedJson[i], entries);
        } else {
          entries.add(
            new _Entry(
              indentLevel: indentLevel,
              prefix: _kListEntryPrefix,
              value: ' ${decodedJson[i]}',
            ),
          );
        }
      }
    } else if (decodedJson is Map) {
      for (Object key in decodedJson.keys) {
        if (decodedJson[key] is List || decodedJson[key] is Map) {
          entries.add(
            new _Entry(indentLevel: indentLevel, prefix: '$key:'),
          );
          _addEntries(indentLevel + 1, decodedJson[key], entries);
        } else {
          entries.add(
            new _Entry(
              indentLevel: indentLevel,
              prefix: '$key:',
              value: ' ${decodedJson[key]}',
            ),
          );
        }
      }
    } else {
      entries.add(
        new _Entry(indentLevel: indentLevel, value: '$decodedJson'),
      );
    }
  }
}

class _Entry extends StatelessWidget {
  final int indentLevel;
  final String prefix;
  final String value;

  const _Entry({this.indentLevel, this.prefix = '', this.value = ''});

  @override
  Widget build(BuildContext context) {
    return new Padding(
      padding: new EdgeInsets.only(
        left: indentLevel * _kJsonViewerEntryIndentPerLevel,
      ),
      child: new Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          new Text(prefix, style: const TextStyle(color: Colors.yellow)),
          new Flexible(
            child: new Text(
              value,
              style: new TextStyle(color: Colors.grey[100]),
            ),
          ),
        ],
      ),
    );
  }
}
