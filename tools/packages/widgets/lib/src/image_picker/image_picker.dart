// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lib.widgets/widgets.dart';
import 'package:meta/meta.dart';
import 'package:search_api/search_api.dart';

import 'image_grid.dart';

/// Callback function signature for selecting a group of images
typedef void ImageSelectCallback(List<String> imageUrls);

const Duration _kSearchDelay = const Duration(milliseconds: 1000);
const String _kSearchMessage = 'Search for images';
const String _kNoImagesMessage = 'No images returned';
const String _kLoadErrorMessage = 'Can\'t load images';
const double _kOverlayHeight = 48.0;
const double _kDefaultFontSize = 14.0;
const double _kSpinnerSize = 48.0;

/// Wrapper around a [ImageGrid] that uses Google Custom Search to populate
/// images based on a given query.
///
/// Requires a valid Google API key and a Custom Search ID:
/// https://developers.google.com/custom-search/
class ImagePicker extends StatefulWidget {
  /// Search API to use for search
  final SearchAPI searchApi;

  /// Optional initial image search query
  final String initialQuery;

  /// Optional list of initial list of selected image urls
  final List<String> initialSelection;

  /// Callback that is fired when the query string is changed
  final ValueChanged<String> onQueryChanged;

  /// Callback that is fired when the set of selected images is changed
  final ImageSelectCallback onSelectionChanged;

  /// Callback that is fired when the user has completed selecting all the
  /// images and wants to "add them"
  final ImageSelectCallback onAdd;

  /// Constructor
  ImagePicker({
    Key key,
    @required this.searchApi,
    this.initialQuery,
    this.initialSelection,
    this.onQueryChanged,
    this.onSelectionChanged,
    this.onAdd,
  })
      : super(key: key) {
    assert(searchApi != null);
  }

  @override
  _ImagePickerState createState() => new _ImagePickerState();
}

class _ImagePickerState extends State<ImagePicker>
    with TickerProviderStateMixin {
  List<String> _sourceImages = <String>[];
  String _lastInputValue;
  TextEditingController _controller;
  bool _isLoading = false;
  Timer _timer;
  String _lastSearchQuery;
  List<String> _selectedImages = <String>[];
  AnimationController _animationController;
  Animation<double> _selectedImagesAnimation;
  // Give a Google query a "count" so that a slower query doesn't overwrite
  // a later query that resolves faster.
  int _counter = 0;
  String _emptyStateMessage = _kSearchMessage;
  bool _enableClearButton = false;

  void _handleInputChange(String value) {
    setState(() {
      // Only call a Google Search query if the text has changed.
      // For example onChanged for an TextField will fire for cursor events.
      if (value != _lastInputValue) {
        _setTimer();
        widget.onQueryChanged?.call(value);
      }
      _lastInputValue = value;
    });
  }

  // Clears search input text when the clear IconButton is pressed
  void _clearInputText() {
    _controller.text = '';
    _handleInputChange(_controller.text);
  }

  // Update the selection from the given list.
  void _updateSelection(List<String> newSelection) {
    List<String> selection = newSelection != null
        ? newSelection
            .where((String url) => _sourceImages.contains(url))
            .toList()
        : <String>[];

    if (selection.isNotEmpty) {
      _selectedImages = selection;
      _animationController.forward();
    } else {
      _clearSelection();
    }
  }

  // Clears all selected images
  void _clearSelection() {
    if (_selectedImages.isNotEmpty) {
      _animationController.reverse();
    }
    setState(() {
      _selectedImages = <String>[];
    });
  }

  String get _selectionText {
    if (_selectedImages.length == 1) {
      return '1 image selected';
    } else {
      return '${_selectedImages.length} images selected';
    }
  }

  // Sets a delay so that we don't make search queries for consecutive
  // keystrokes.
  void _setTimer() {
    _timer?.cancel();
    _timer = new Timer(_kSearchDelay, () => _search(_controller.text, null));
  }

  bool get _hideEmptyState => _isLoading || _sourceImages.isNotEmpty;

  Future<Null> _search(String query, List<String> initialSelection) async {
    if (query == _lastSearchQuery) {
      return null;
    }
    if (query.isEmpty) {
      setState(() {
        _sourceImages = <String>[];
        _emptyStateMessage = _kSearchMessage;
        _enableClearButton = false;
      });
    } else {
      _counter++;
      int currentCount = _counter;
      setState(() {
        _isLoading = true;
      });
      List<String> images = await widget.searchApi.images(query: query);
      if (currentCount == _counter) {
        setState(() {
          _lastSearchQuery = query;
          _sourceImages = images ?? <String>[];
          _enableClearButton = true;
          _isLoading = false;
          _updateSelection(initialSelection);

          if (images == null) {
            _emptyStateMessage = _kLoadErrorMessage;
          } else if (_sourceImages.isEmpty &&
              (_lastSearchQuery?.isNotEmpty ?? false) &&
              (_lastInputValue?.isNotEmpty ?? false) &&
              _controller.text.isNotEmpty) {
            _emptyStateMessage = _kNoImagesMessage;
          } else {
            _emptyStateMessage = _kSearchMessage;
          }
        });
      }
    }
  }

  Widget _createEmptyState() {
    return new Positioned.fill(
      child: new AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget child) {
          return new Offstage(
            offstage: _hideEmptyState,
            child: child,
          );
        },
        child: new Material(
          child: new Center(
            child: new Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                new Icon(
                  Icons.collections,
                  color: Colors.grey[300],
                  size: 100.0,
                ),
                new Text(
                  _emptyStateMessage,
                  style: new TextStyle(
                    fontSize: 16.0,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _controller = new TextEditingController(text: widget.initialQuery);
    _lastInputValue = _controller.text;
    _animationController = new AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _selectedImagesAnimation = new CurvedAnimation(
      parent: _animationController,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.fastOutSlowIn,
    );

    if (widget.initialQuery != null && widget.initialQuery.isNotEmpty) {
      _search(widget.initialQuery, widget.initialSelection);
    }
  }

  @override
  void didUpdateWidget(ImagePicker oldWidget) {
    super.didUpdateWidget(oldWidget);

    String oldQuery = _controller.text;
    String newQuery = widget.initialQuery ?? '';
    if (oldQuery != newQuery) {
      _controller.text = newQuery;
      _controller.selection = new TextSelection.collapsed(
        offset: newQuery.length,
      );
      _search(newQuery, widget.initialSelection);
    }

    _updateSelection(widget.initialSelection);
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget searchInput = new Container(
      decoration: new BoxDecoration(
        border: new Border(
          bottom: new BorderSide(
            color: Colors.grey[200],
          ),
        ),
      ),
      child: new Row(
        children: <Widget>[
          new Container(
            padding: const EdgeInsets.all(12.0),
            child: new Icon(
              Icons.search,
              color: Colors.grey[900],
            ),
          ),
          new Expanded(
            child: new TextField(
              controller: _controller,
              onChanged: _handleInputChange,
              decoration: new InputDecoration.collapsed(
                hintText: 'Search',
                hintStyle: new TextStyle(
                  color: Colors.grey[500],
                  fontSize: _kDefaultFontSize,
                ),
              ),
            ),
          ),
          new IconButton(
            icon: new Icon(Icons.clear),
            color: Colors.grey[900],
            disabledColor: Colors.grey[50],
            onPressed: _enableClearButton ? _clearInputText : null,
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
            child: new SizedBox(
              width: _kSpinnerSize,
              height: _kSpinnerSize,
              child: new FuchsiaSpinner(),
            ),
          ),
        ),
      ),
    );
    ImageGrid imageGrid = new ImageGrid(
      imageUrls: _sourceImages,
      selectedImages: _selectedImages,
      onImageTap: (String url) {
        setState(() {
          if (_selectedImages.contains(url)) {
            _selectedImages.remove(url);
            if (_selectedImages.length == 0) {
              _animationController.reverse();
            }
          } else {
            _selectedImages.add(url);
            if (_selectedImages.length == 1) {
              _animationController.forward();
            }
          }
        });
        widget.onSelectionChanged?.call(_selectedImages);
      },
    );
    Widget selectedImagesOverlay = new AnimatedBuilder(
      animation: _animationController,
      builder: (BuildContext context, Widget child) {
        return new Positioned(
          height: _kOverlayHeight,
          left: 0.0,
          right: 0.0,
          top: -(_kOverlayHeight + 16.0) *
              (1.0 - _selectedImagesAnimation.value),
          child: new Offstage(
            offstage: _animationController.isDismissed,
            child: child,
          ),
        );
      },
      child: new Material(
        elevation: 2.0,
        child: new Container(
          padding: const EdgeInsets.only(left: 12.0),
          child: new Row(
            children: <Widget>[
              new Expanded(
                child: new Text(
                  _selectionText,
                  style: new TextStyle(
                    fontSize: _kDefaultFontSize,
                  ),
                ),
              ),
              new IconButton(
                icon: new Icon(Icons.check),
                color: Colors.grey[900],
                onPressed: () => widget.onAdd?.call(_selectedImages),
              ),
              new IconButton(
                icon: new Icon(Icons.clear),
                color: Colors.grey[900],
                onPressed: () {
                  _clearSelection();
                  widget.onSelectionChanged?.call(_selectedImages);
                },
              ),
            ],
          ),
        ),
      ),
    );

    return new Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        new Stack(
          fit: StackFit.passthrough,
          children: <Widget>[
            searchInput,
            selectedImagesOverlay,
          ],
        ),
        new Expanded(
          child: new Stack(
            fit: StackFit.passthrough,
            children: <Widget>[
              imageGrid,
              loadingOverlay,
              _createEmptyState(),
            ],
          ),
        ),
      ],
    );
  }
}
