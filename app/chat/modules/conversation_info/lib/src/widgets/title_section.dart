// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// A widget representing the title editing section of the info module.
class TitleSection extends StatefulWidget {
  /// The initial title value.
  final String initialTitle;

  /// Called when a new title value is submitted.
  final ValueChanged<String> onTitleSubmitted;

  /// Creates a new instance of [TitleSection].
  const TitleSection({
    Key key,
    this.initialTitle,
    this.onTitleSubmitted,
  })
      : super(key: key);

  @override
  _TitleSectionState createState() => new _TitleSectionState();
}

class _TitleSectionState extends State<TitleSection> {
  final TextEditingController _controller = new TextEditingController();

  bool get _canUpdateTitle =>
      _effectiveText.isNotEmpty && _effectiveText != widget.initialTitle;

  String get _effectiveText => _controller.text.trim();

  @override
  void initState() {
    super.initState();

    _controller.text = widget.initialTitle?.trim() ?? '';
  }

  @override
  void didUpdateWidget(TitleSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialTitle != widget.initialTitle) {
      _controller.text = widget.initialTitle?.trim() ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return new Padding(
      padding: const EdgeInsets.all(16.0),
      child: new Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          new TextField(
            decoration: const InputDecoration(labelText: 'Title'),
            controller: _controller,
            onSubmitted: (String text) {
              if (_canUpdateTitle) {
                widget.onTitleSubmitted?.call(_effectiveText);
              }
            },
          ),
          new ButtonTheme.bar(
            child: new ButtonBar(
              children: <Widget>[
                new AnimatedBuilder(
                  animation: _controller,
                  builder: (BuildContext context, Widget child) {
                    return new FlatButton(
                      onPressed: _canUpdateTitle
                          ? () => widget.onTitleSubmitted?.call(_effectiveText)
                          : null,
                      child: const Text('UPDATE'),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
