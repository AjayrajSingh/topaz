// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'ask_model.dart';

class AskTextField extends StatelessWidget {
  final AskModel model;

  const AskTextField({this.model});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model.animation,
      child: Material(
        color: Colors.black,
        elevation: model.elevation,
        child: FractionallySizedBox(
          widthFactor: 0.5,
          child: TextField(
            controller: model.controller,
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.search,
                color: Colors.white54,
                size: 24.0,
              ),
              border: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: Colors.white),
              ),
              hintText: '#Ask for anything',
              hintStyle: Theme.of(context).textTheme.subhead.merge(
                    TextStyle(
                      color: Colors.white30,
                      fontFamily: 'RobotoMono',
                    ),
                  ),
            ),
            style: Theme.of(context).textTheme.subhead.merge(
                  TextStyle(
                    color: Colors.white,
                    fontFamily: 'RobotoMono',
                  ),
                ),
            focusNode: model.focusNode,
            onChanged: model.onQuery,
            onSubmitted: model.onAsk,
          ),
        ),
      ),
      builder: (context, child) {
        return Transform.scale(
          scale: model.animation.value,
          child: child,
        );
      },
    );
  }
}
