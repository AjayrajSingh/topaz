// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/widgets.dart';

TextStyle _titleTextStyle(double scale) => new TextStyle(
      color: Colors.grey[900],
      fontSize: 48.0 * scale,
      fontWeight: FontWeight.w200,
    );

TextStyle _subTitleTextStyle(double scale) => new TextStyle(
      color: Colors.grey[900],
      fontSize: 48.0 * scale,
      fontWeight: FontWeight.w200,
    );

TextStyle _textStyle(double scale) => new TextStyle(
      color: Colors.grey[900],
      fontSize: 24.0 * scale,
      fontWeight: FontWeight.w200,
    );

/// A single page displayed in a settings app.
class SettingsPage extends StatelessWidget {
  /// Whether or not to display a spinner
  final bool isLoading;

  /// The label to be shown for the entire page
  final String title;

  /// The subsections of the settings page
  final List<SettingsSection> sections;

  /// The scale at which to render the text
  final double scale;

  /// Constructor.
  const SettingsPage(
      {this.isLoading: false, this.title, @required this.scale, this.sections});

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[];

    if (title != null) {
      children.add(new Text(title, style: _titleTextStyle(scale)));
    }

    if (isLoading) {
      children.add(new Expanded(
        child: new Center(
            child: new Container(
          width: 64.0,
          height: 64.0,
          child: new FuchsiaSpinner(),
        )),
      ));
      return new Column(children: children);
    }

    children.addAll(sections);

    return new ListView(
        padding: new EdgeInsets.all(16.0 * scale), children: children);
  }
}

/// A subsection of a settings page, with an optional title.
///
/// All subsections should be fixed height widgets.
class SettingsSection extends StatelessWidget {
  /// String displayed at the top of the section
  final String title;

  /// Contents of the section
  final Widget child;

  /// Scale at which to render the text
  final double scale;

  /// Constructor.
  const SettingsSection(
      {@required this.title, @required this.child, @required this.scale});

  @override
  Widget build(BuildContext context) {
    if (title != null) {
      return new Column(children: <Widget>[
        new Text(title, style: _subTitleTextStyle(scale)),
        child
      ]);
    }
    return child;
  }
}

/// A list of items such as devices or toggles.
class SettingsItemList extends StatelessWidget {
  /// A list of child items in a settings item
  final List<SettingsItem> items;

  /// Constructs a new list with the settings items
  const SettingsItemList({@required this.items});

  @override
  Widget build(BuildContext context) {
    return new Column(children: items);
  }
}

/// A settings item should have a flexible width but height as specified
abstract class SettingsItem extends StatelessWidget {
  static const double _unscaledHeight = 48.0;

  /// Scaling factor to render widget
  final double scale;

  /// Builds a new settings item with the specified scale.
  const SettingsItem(this.scale);

  /// Total height of a single settings item.
  double get height => _unscaledHeight * scale;
}

/// A tile that can be used to display a
class SettingsTile extends SettingsItem {
  /// The asset to be displayed
  ///
  /// Only should be set if [iconData] is not
  final String assetUrl;

  /// The icon to be displayed.
  ///
  /// Only should be set if [assetUrl] is not
  final IconData iconData;

  /// The label to display next to the icon
  final String text;

  /// A string displaying the status, errors, or
  /// other secondary text.
  final String description;

  /// Callback to run when the network is tapped
  final VoidCallback onTap;

  /// Constructs a new settings item
  const SettingsTile(
      {@required this.text,
      this.assetUrl,
      this.iconData,
      this.description,
      this.onTap,
      @required double scale})
      : super(scale);

  @override
  Widget build(BuildContext context) {
    return new ListTile(
        leading: _buildLogo(),
        title: _title(),
        subtitle: _subTitle(),
        onTap: onTap);
  }

  Widget _buildLogo() {
    assert(iconData != null || assetUrl != null);
    assert(iconData == null || assetUrl == null);

    Widget logo = iconData != null
        ? new Icon(iconData, size: height, color: Colors.grey[900])
        : new Image.asset(
            assetUrl,
            height: height,
            width: height,
          );

    return new Container(
        padding: new EdgeInsets.only(
          right: 16.0 * scale,
        ),
        child: logo);
  }

  Widget _title() => new Text(text, style: _textStyle(scale));

  Widget _subTitle() => new Text(description, style: _textStyle(scale));
}
