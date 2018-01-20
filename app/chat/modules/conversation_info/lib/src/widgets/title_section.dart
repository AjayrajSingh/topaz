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
  bool _editingTitle = false;

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
      _stopEditingTitle();
    }
  }

  Widget _buildTitle(BuildContext context) {
    ThemeData theme = Theme.of(context);

    if (_editingTitle) {
      return new TextField(
        autofocus: true,
        controller: _controller,
        decoration: const InputDecoration.collapsed(hintText: ''),
        style: theme.textTheme.title,
        onSubmitted: (String _) {
          if (_canUpdateTitle) {
            _submitTitle();
          }
        },
      );
    } else {
      return new Text(
        widget.initialTitle ?? '',
        style: theme.textTheme.title,
        overflow: TextOverflow.ellipsis,
      );
    }
  }

  Widget _buildButton(BuildContext context) {
    return _editingTitle
        ? new AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget child) {
              return new IconButton(
                icon: new Icon(Icons.check),
                onPressed: _canUpdateTitle ? _submitTitle : null,
              );
            },
          )
        : new IconButton(
            icon: new Icon(Icons.edit),
            onPressed: _startEditingTitle,
          );
  }

  @override
  Widget build(BuildContext context) {
    return new Container(
      height: 56.0,
      padding: const EdgeInsetsDirectional.only(start: 16.0),
      alignment: FractionalOffset.centerLeft,
      decoration: new BoxDecoration(
        border: new Border(bottom: new BorderSide(color: Colors.grey[300])),
      ),
      child: new Row(
        children: <Widget>[
          new Expanded(child: _buildTitle(context)),
          _buildButton(context),
        ],
      ),
    );
  }

  void _startEditingTitle() {
    setState(() {
      _editingTitle = true;

      _controller
        ..text = widget.initialTitle
        ..selection = new TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
    });
  }

  void _stopEditingTitle() {
    setState(() {
      _editingTitle = false;
      _controller.clear();
    });
  }

  void _submitTitle() {
    String title = _controller.text;

    widget.onTitleSubmitted?.call(title);
    _stopEditingTitle();
  }
}
