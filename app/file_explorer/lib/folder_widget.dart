// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter/material.dart';

const TextStyle _kFolderTextStyle = const TextStyle(
  color: Colors.white,
  fontSize: 20.0,
  fontWeight: FontWeight.w700,
  decoration: TextDecoration.none,
);
const TextStyle _kFileTextStyle = const TextStyle(
  color: Colors.white,
  fontSize: 16.0,
  fontWeight: FontWeight.w300,
  decoration: TextDecoration.none,
);
const EdgeInsets _kIndent = const EdgeInsets.only(left: 24.0);

/// Displays a folder.
class FolderWidget extends StatefulWidget {
  /// The path of the folder.
  final String path;

  /// Constructor.
  const FolderWidget({this.path});

  @override
  _FolderWidgetState createState() => new _FolderWidgetState();
}

class _FolderWidgetState extends State<FolderWidget> {
  List<FileSystemEntity> _listing;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    new Directory(widget.path)
        .list()
        .toList()
        .then((List<FileSystemEntity> listing) {
      if (mounted) {
        setState(() {
          _listing = listing;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = <Widget>[
      new GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() {
              _show = !_show;
            }),
        child: new Container(
          color: Colors.grey[800],
          child: new ConstrainedBox(
            constraints: new BoxConstraints(minWidth: 100.0),
            child: new Text(
                '${Uri.parse(widget.path).pathSegments.isEmpty ? '' : Uri.parse(widget.path).pathSegments.last}/',
                style: _kFolderTextStyle),
          ),
        ),
      )
    ];
    if (_show) {
      if (_listing != null) {
        if (_listing.isEmpty) {
          children.add(
            new Container(
              color: Colors.black,
              child: const Padding(
                padding: _kIndent,
                child: const Text('<EMPTY>', style: _kFileTextStyle),
              ),
            ),
          );
        } else {
          children.addAll(_listing.map((FileSystemEntity entity) {
            if (entity is Directory) {
              return new Container(
                color: Colors.black,
                child: new Padding(
                  padding: _kIndent,
                  child: new FolderWidget(path: entity.path),
                ),
              );
            } else {
              return new Container(
                color: Colors.black,
                child: new Padding(
                  padding: _kIndent,
                  child: new Text(
                    Uri.parse(entity.path).pathSegments.last,
                    style: _kFileTextStyle,
                  ),
                ),
              );
            }
          }));
        }
      } else {
        children.add(
          new Container(
            color: Colors.black,
            child: const Padding(
              padding: _kIndent,
              child: const Text('<...loading...>', style: _kFileTextStyle),
            ),
          ),
        );
      }
    }
    return new Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
