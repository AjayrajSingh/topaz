// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:flutter/material.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

import 'src/modular/module_model.dart';

const double _kJsonViewerElevation = 1.0;
const double _kJsonViewerBorderRadius = 8.0;
const double _kJsonViewerListViewInset = 16.0;
const double _kJsonViewerEntryIndentPerLevel = 32.0;

const String _kListEntryPrefix = '\u{2022} '; // Unicode bullet point.

/// Main entry point to the link_viewer module.
void main() {
  setupLogger();

  ModuleWidget<LinkViewerModuleModel> moduleWidget =
      new ModuleWidget<LinkViewerModuleModel>(
    applicationContext: new ApplicationContext.fromStartupInfo(),
    moduleModel: new LinkViewerModuleModel(),
    child: new PhysicalModel(
      color: Colors.black,
      elevation: _kJsonViewerElevation,
      borderRadius: new BorderRadius.circular(_kJsonViewerBorderRadius),
      child: new _JsonViewer(),
    ),
  );

  moduleWidget.advertise();

  runApp(moduleWidget);
}

class _JsonViewer extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      new ScopedModelDescendant<LinkViewerModuleModel>(
        builder: (_, __, LinkViewerModuleModel model) {
          List<_JsonEntry> entries = <_JsonEntry>[];
          _addEntries(0, model.decodedJson, entries);
          return new ListView.builder(
            padding: const EdgeInsets.all(_kJsonViewerListViewInset),
            physics: const BouncingScrollPhysics(),
            itemCount: entries.length,
            itemBuilder: (BuildContext context, int index) => entries[index],
          );
        },
      );

  void _addEntries(
    int indentLevel,
    dynamic decodedJson,
    List<_JsonEntry> entries,
  ) {
    if (decodedJson is List) {
      for (int i = 0; i < decodedJson.length; i++) {
        if (decodedJson[i] is List || decodedJson[i] is Map) {
          entries.add(
            new _JsonEntry(
              indentLevel: indentLevel,
              prefix: _kListEntryPrefix,
              decodedJson: '',
            ),
          );
          _addEntries(indentLevel + 1, decodedJson[i], entries);
        } else {
          entries.add(
            new _JsonEntry(
              indentLevel: indentLevel,
              prefix: _kListEntryPrefix,
              decodedJson: decodedJson[i],
            ),
          );
        }
      }
    } else if (decodedJson is Map) {
      decodedJson.keys.forEach(
        (dynamic key) {
          if (decodedJson[key] is List || decodedJson[key] is Map) {
            entries.add(
              new _JsonEntry(
                indentLevel: indentLevel,
                prefix: '$key: ',
                decodedJson: '',
              ),
            );
            _addEntries(indentLevel + 1, decodedJson[key], entries);
          } else {
            entries.add(
              new _JsonEntry(
                indentLevel: indentLevel,
                prefix: '$key: ',
                decodedJson: decodedJson[key],
              ),
            );
          }
        },
      );
    } else {
      entries.add(
        new _JsonEntry(indentLevel: indentLevel, decodedJson: decodedJson),
      );
    }
  }
}

class _JsonEntry extends StatelessWidget {
  final int indentLevel;
  final String prefix;
  final dynamic decodedJson;

  _JsonEntry({this.indentLevel, this.prefix: '', this.decodedJson});

  @override
  Widget build(BuildContext context) {
    return new Padding(
      padding: new EdgeInsets.only(
        left: indentLevel * _kJsonViewerEntryIndentPerLevel,
      ),
      child: new Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          new Text(prefix, style: new TextStyle(color: Colors.yellow)),
          new Expanded(
            child: new Text(
              '$decodedJson',
              style: new TextStyle(color: Colors.grey[100]),
            ),
          ),
        ],
      ),
    );
  }
}
