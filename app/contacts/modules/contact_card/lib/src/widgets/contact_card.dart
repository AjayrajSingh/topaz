// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/modular.dart';

import '../models/contact_card_model.dart';
import 'contact_activity.dart';
import 'contact_details.dart';
import 'header.dart';

const double _kListPortraitWidth = 0.4;
const String _kEmptyContactMsg =
    'Sorry, the contact does not exist or was never specified. :(';

/// The UI widget that shows the details of a contact
class ContactCard extends StatefulWidget {
  @override
  _ContactCardState createState() => new _ContactCardState();
}

class _ContactCardState extends State<ContactCard>
    with SingleTickerProviderStateMixin {
  TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = new TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return new ScopedModelDescendant<ContactCardModel>(
      builder: (
        BuildContext context,
        Widget child,
        ContactCardModel model,
      ) {
        return model.contact == null
            ? const Center(child: const Text(_kEmptyContactMsg))
            : new LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  bool isPortrait =
                      (constraints.maxWidth < constraints.maxHeight);
                  double listWidth = isPortrait
                      ? constraints.maxWidth
                      : constraints.maxWidth * _kListPortraitWidth;
                  Header header = new Header(
                    displayName: model.contact.displayName,
                    photoUrl: model.contact.photoUrl,
                  );
                  ContactDetails details = new ContactDetails(
                    contact: model.contact,
                  );
                  ContactActivity activity = new ContactActivity(
                    showHeader: !isPortrait,
                  );

                  return isPortrait
                      ? _buildPortraitView(header, details, activity)
                      : new Row(
                          children: <Widget>[
                            new Container(
                              width: listWidth,
                              child: new Column(children: <Widget>[
                                header,
                                new Expanded(child: details),
                              ]),
                            ),
                            new Expanded(child: activity),
                          ],
                        );
                },
              );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Details and Activity are combined into a tab view
  Widget _buildPortraitView(Widget header, Widget details, Widget activity) {
    return new Column(
      children: <Widget>[
        header,
        new TabBar(
          indicatorColor: Colors.blue,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey[500],
          controller: _controller,
          tabs: const <Tab>[
            const Tab(text: 'Details'),
            const Tab(text: 'Activity'),
          ],
        ),
        new Expanded(
          child: new TabBarView(
            controller: _controller,
            children: <Widget>[details, activity],
          ),
        ),
      ],
    );
  }
}
