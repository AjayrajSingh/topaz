// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_search_api/google_search_api.dart';
import 'package:meta/meta.dart';

import 'image_picker.dart';

const Duration _kSearchDelay = const Duration(milliseconds: 500);

/// Wrapper around a [ImagePicker] that uses Google Custom Search to populate
/// images based on a given query.
///
/// Requires a valid Google API key and a Custom Search ID:
/// https://developers.google.com/custom-search/
class GoogleSearchImagePicker extends StatefulWidget {
  /// API key used for a Custom Google Search
  final String apiKey;

  /// ID of the Custom Google Search instance
  final String customSearchId;

  /// Callback that is fired when the user has completed selecting all the
  /// images and wants to "add them"
  final ImageSelectCallback onAdd;

  /// optional initial image search query
  final String query;

  /// Constructor
  GoogleSearchImagePicker({
    Key key,
    @required this.apiKey,
    @required this.customSearchId,
    this.query,
    this.onAdd,
  })
      : super(key: key) {
    assert(apiKey != null);
    assert(customSearchId != null);
  }

  @override
  _GoogleSearchImagePickerState createState() =>
      new _GoogleSearchImagePickerState();
}

class _GoogleSearchImagePickerState extends State<GoogleSearchImagePicker> {
  List<String> _sourceImages = <String>[];
  InputValue _currentInput = InputValue.empty;
  bool _isLoading = false;
  Timer _timer;
  // Give a Google query a "count" so that a slower query doesn't overwrite
  // a later query that resolves faster.
  int _counter = 0;

  void _handleInputChange(InputValue input) {
    setState(() {
      // Only call a Google Search query if the text has changed.
      // For example onChanged for an InputField will fire for cursor events.
      if (input.text != _currentInput.text) {
        _setTimer();
      }
      _currentInput = input;
    });
  }

  // Sets a delay so that we don't make search queries for consecutive
  // keystrokes.
  void _setTimer() {
    _timer?.cancel();
    _timer = new Timer(_kSearchDelay, () => _search(_currentInput.text));
  }

  bool get _hideEmptyState =>
      _isLoading || _sourceImages.isNotEmpty || _currentInput.text.isNotEmpty;

  Future<Null> _search(String query) async {
    if (query.isEmpty) {
      setState(() {
        _sourceImages = <String>[];
      });
    } else {
      _counter++;
      int currentCount = _counter;
      setState(() {
        _isLoading = true;
      });
      List<String> images = await GoogleSearchAPI.images(
        query: query,
        apiKey: config.apiKey,
        customSearchId: config.customSearchId,
      );
      if (currentCount == _counter) {
        setState(() {
          _sourceImages = images;
          _isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (config.query != null && config.query.isNotEmpty) {
      _currentInput = new InputValue(text: config.query);
      _search(config.query);
    }
  }

  @override
  void didUpdateConfig(GoogleSearchImagePicker oldState) {
    super.didUpdateConfig(oldState);
    // Make a new search if config.query has been changed
    if (oldState.query == _currentInput.text) {
      _currentInput = new InputValue(text: config.query);
      _search(config.query);
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Widget searchInput = new Container(
      padding: const EdgeInsets.all(8.0),
      margin: const EdgeInsets.only(bottom: 4.0),
      decoration: new BoxDecoration(
        border: new Border(
          bottom: new BorderSide(
            color: Colors.grey[300],
          ),
        ),
      ),
      child: new Row(
        children: <Widget>[
          new Container(
            margin: const EdgeInsets.only(right: 8.0),
            child: new Icon(
              Icons.search,
              color: theme.primaryColor,
            ),
          ),
          new Expanded(
            child: new InputField(
              hintText: 'search images',
              value: _currentInput,
              onChanged: _handleInputChange,
            ),
          ),
        ],
      ),
    );
    Widget loadingOverlay = new Positioned.fill(
      child: new Offstage(
        offstage: !_isLoading,
        child: new Material(
          color: Colors.white.withAlpha(100),
          child: new Center(
            child: new CircularProgressIndicator(
              value: null,
              valueColor: new AlwaysStoppedAnimation<Color>(theme.primaryColor),
            ),
          ),
        ),
      ),
    );
    Widget emptyState = new Positioned.fill(
      child: new Offstage(
        offstage: _hideEmptyState,
        child: new Material(
          color: Colors.white,
          child: new Center(
            child: new Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                new Icon(
                  Icons.image,
                  color: Colors.grey[400],
                  size: 56.0,
                ),
                new Text(
                  'type to search for images',
                  style: new TextStyle(
                    fontSize: 20.0,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return new Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        searchInput,
        new Expanded(
          child: new Stack(
            children: <Widget>[
              new ImagePicker(
                imageUrls: _sourceImages,
              ),
              loadingOverlay,
              emptyState,
            ],
          ),
        ),
      ],
    );
  }
}
