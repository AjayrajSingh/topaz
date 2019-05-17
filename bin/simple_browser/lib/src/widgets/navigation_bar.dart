// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import '../blocs/browser_bloc.dart';
import '../models/browse_action.dart';

class NavigationBar extends StatelessWidget {
  final BrowserBloc bloc;

  const NavigationBar({this.bloc});

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.all(8.0),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: StreamBuilder<bool>(
                stream: bloc.backState,
                initialData: false,
                builder: (context, snapshot) => RaisedButton(
                      padding: EdgeInsets.all(4),
                      child: Text('BCK'),
                      color: Colors.grey[350],
                      disabledColor: Colors.grey[700],
                      onPressed: snapshot.data
                          ? () => bloc.request.add(GoBackAction())
                          : null,
                    ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: StreamBuilder<bool>(
                stream: bloc.forwardState,
                initialData: false,
                builder: (context, snapshot) => RaisedButton(
                      padding: EdgeInsets.all(4),
                      child: Text('FWD'),
                      color: Colors.grey[350],
                      disabledColor: Colors.grey[700],
                      onPressed: snapshot.data
                          ? () => bloc.request.add(GoForwardAction())
                          : null,
                    ),
              ),
            ),
            NavigationBox(bloc: bloc),
          ],
        ));
  }
}

class NavigationBox extends StatefulWidget {
  final BrowserBloc bloc;

  const NavigationBox({this.bloc});

  @override
  NavigationBoxState createState() => NavigationBoxState(bloc);
}

class NavigationBoxState extends State<NavigationBox> {
  final TextEditingController _controller;

  NavigationBoxState(BrowserBloc bloc) : _controller = TextEditingController() {
    bloc.url.listen((url) {
      _controller.text = url;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          filled: true,
          border: InputBorder.none,
          fillColor: Colors.white,
          hintText: 'Enter an address...',
        ),
        onSubmitted: (value) =>
            widget.bloc.request.add(NavigateToAction(url: value)),
        textInputAction: TextInputAction.go,
      ),
    );
  }
}
