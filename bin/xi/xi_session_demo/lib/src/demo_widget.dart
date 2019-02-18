// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:fuchsia_scenic_flutter/child_view.dart' show ChildView;
import 'package:lib.widgets.dart/model.dart';

import 'demo_model.dart';

class MessagesDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Embedded Xi Demo',
      home: ScopedModelDescendant<DemoModel>(
        builder: (BuildContext context, Widget child, DemoModel model) =>
            Scaffold(
              floatingActionButton: model.showingModal
                  ? null
                  : FloatingActionButton(
                      child: Icon(Icons.add),
                      backgroundColor: Colors.pink[200],
                      onPressed: () => model.composeButtonAction()),
              body: mainWidget(model),
            ),
      ),
    );
  }
}

Widget mainWidget(DemoModel model) {
  final messageList = MessageList(model.messages);
  if (!model.showingModal) {
    return messageList;
  }

  return Stack(children: <Widget>[
    messageList,
    Center(
      child: FractionallySizedBox(
        heightFactor: 0.9,
        widthFactor: 0.9,
        alignment: Alignment.center,
        child: DecoratedBox(
          decoration: BoxDecoration(boxShadow: [
            BoxShadow(blurRadius: 5.0, offset: Offset(2.0, 2.0))
          ]),
          child: Scaffold(
            floatingActionButton: FloatingActionButton(
                child: Text('Send'), onPressed: () => model.sendButtonAction()),
            body: model.editorConn != null
                ? new ChildView(connection: model.editorConn)
                : new Placeholder(),
          ),
        ),
      ),
    )
  ]);
}

/// Displays a list of 'messages' in the style of a messaging app.
class MessageList extends StatelessWidget {
  final List<String> _messages;

  const MessageList(this._messages) : assert(_messages != null);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(8.0),
      children: _messages
          .map(
            (msg) => Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1.0,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.pink[200],
                        borderRadius: BorderRadius.circular(5.0),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Text(
                          msg,
                          style: TextStyle(
                            fontSize: 16.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          )
          .toList(),
    );
  }
}
