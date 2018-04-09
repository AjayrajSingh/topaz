// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/modular.dart';
import 'package:meta/meta.dart';

import '../../models.dart';
import 'contact_list_item.dart';

// Strings
const String _kContacts = 'Contact';
const String _kSearchFieldHint = 'Search';
const String _kBackHint = 'Back';
const String _kClearHint = 'Clear';

// UI Constants
const double _kHeaderHeight = 56.0;

/// The UI widget that represents a list of contacts
/// TODO(meiyili) SO-765: add loading indicators for all async calls
class ContactList extends StatefulWidget {
  /// Method to call to search for contacts
  final SearchContactsAction onQueryChanged;

  /// Method to call to clear the search results list
  final ClearSearchResultsAction onQueryCleared;

  /// Method to call when the user taps on a contact item
  final ContactTappedAction onContactTapped;

  /// Method to call to refresh the list of contacts
  final RefreshContactsAction onRefreshContacts;

  /// Creates a new instance of [ContactList]
  const ContactList({
    Key key,
    @required this.onQueryChanged,
    @required this.onQueryCleared,
    @required this.onContactTapped,
    @required this.onRefreshContacts,
  })  : assert(onQueryChanged != null),
        assert(onQueryCleared != null),
        assert(onContactTapped != null),
        assert(onRefreshContacts != null),
        super(key: key);

  @override
  _ContactListState createState() => new _ContactListState();
}

class _ContactListState extends State<ContactList>
    with TickerProviderStateMixin {
  final TextEditingController _textController = new TextEditingController();
  final FocusNode _textFieldFocusNode = new FocusNode();

  AnimationController _animationController;
  Animation<double> _searchBarAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = new AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _searchBarAnimation = new CurvedAnimation(
      parent: _animationController,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.fastOutSlowIn,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _textController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return new Scaffold(
      body: new ScopedModelDescendant<ContactListModel>(
        builder: (
          BuildContext context,
          Widget child,
          ContactListModel model,
        ) {
          return new Center(
            child: new Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildHeader(theme),
                new Expanded(
                  child: _buildList(model),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: new FloatingActionButton(
        onPressed: widget.onRefreshContacts,
        tooltip: 'Refresh contact list',
        child: new Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return new Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        new Container(
          height: _kHeaderHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          decoration: const BoxDecoration(
            border: const Border(
              bottom:
                  const BorderSide(color: const Color(0xFFE0E0E0)), // grey 300
            ),
          ),
          child: new Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                new Text(_kContacts, style: theme.textTheme.title),
                new IconButton(
                  icon: new Icon(Icons.search),
                  tooltip: _kSearchFieldHint,
                  onPressed: _showSearchTextField,
                  color: theme.textTheme.title.color,
                ),
              ]),
        ),
        // Text field that will go over top of the header
        _buildSearchFieldOverlay(theme),
      ],
    );
  }

  Widget _buildSearchFieldOverlay(ThemeData theme) {
    TextField textField = new TextField(
      autofocus: false,
      focusNode: _textFieldFocusNode,
      decoration: const InputDecoration(hintText: _kSearchFieldHint),
      controller: _textController,
      onChanged: _onSearchFieldChange,
      style: theme.textTheme.subhead,
    );

    return new AnimatedBuilder(
      animation: _searchBarAnimation,
      builder: (BuildContext context, Widget child) {
        return new Positioned(
          height: _kHeaderHeight,
          left: 0.0,
          right: 0.0,
          top: -_kHeaderHeight * (1.0 - _searchBarAnimation.value),
          child: new Offstage(
            offstage: _searchBarAnimation.isDismissed,
            child: child,
          ),
        );
      },
      child: new Material(
        elevation: 2.0,
        child: new Container(
          color: Colors.grey[200],
          padding: const EdgeInsets.only(left: 3.0),
          child: new Row(
            children: <Widget>[
              new IconButton(
                icon: new Icon(Icons.arrow_back),
                tooltip: _kBackHint,
                onPressed: _hideSearchTextField,
                color: theme.textTheme.subhead.color,
              ),
              new Expanded(
                child: textField,
              ),
              new IconButton(
                icon: new Icon(Icons.close),
                tooltip: _kClearHint,
                onPressed: _clearTextField,
                color: theme.textTheme.subhead.color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(ContactListModel model) {
    return new AnimatedBuilder(
      animation: _animationController,
      builder: (BuildContext context, Widget child) {
        return new Stack(
          children: <Widget>[
            new Offstage(
              offstage: _animationController.isCompleted,
              child: new Opacity(
                opacity: 1.0 - _animationController.value,
                child: _buildContactsList(model),
              ),
            ),
            new Offstage(
              offstage: _animationController.isDismissed,
              child: new Opacity(
                opacity: _animationController.value,
                child: _buildSearchResultsList(model),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContactsList(ContactListModel model) {
    return new ListView(
      children: model.contacts.map((ContactItem c) {
        return new ContactListItem(
          contact: c,
          onContactTapped: widget.onContactTapped,
          isFirstInCategory: model.firstItems.contains(c),
        );
      }).toList(),
    );
  }

  Widget _buildSearchResultsList(ContactListModel model) {
    return new ListView(
      children: model.searchResults.map((ContactItem c) {
        return new ContactListItem(
          contact: c,
          onContactTapped: widget.onContactTapped,
          isFirstInCategory: model.firstItems.contains(c),
        );
      }).toList(),
    );
  }

  void _onSearchFieldChange(String prefix) {
    if (prefix.isEmpty) {
      widget.onQueryCleared();
    } else {
      widget.onQueryChanged(prefix);
    }
  }

  void _showSearchTextField() {
    FocusScope.of(context).requestFocus(_textFieldFocusNode);
    _animationController.forward();
  }

  void _hideSearchTextField() {
    _textFieldFocusNode.unfocus();
    _animationController.reverse();
  }

  void _clearTextField() {
    _textController.clear();
    widget.onQueryCleared();
  }
}
