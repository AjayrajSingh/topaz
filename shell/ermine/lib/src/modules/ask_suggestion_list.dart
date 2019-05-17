// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'ask_model.dart';

const _kListItemHeight = 24.0;
const _kListItemMargin = 8.0;

class AskSuggestionList extends StatelessWidget {
  final AskModel model;

  const AskSuggestionList({this.model});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model.suggestions,
      builder: (context, child) => RawKeyboardListener(
            onKey: model.onKey,
            focusNode: model.focusNode,
            child: SliverList(
              delegate: SliverChildBuilderDelegate(
                _buildItem,
                childCount: model.suggestions.value.length,
              ),
            ),
          ),
    );
  }

  Widget _buildItem(context, index) {
    final suggestion = model.suggestions.value[index];
    return Listener(
      onPointerEnter: (_) {
        model.selection.value = index;
      },
      onPointerExit: (_) {
        if (model.selection.value == index) {
          model.selection.value = -1;
        }
      },
      child: GestureDetector(
        onTap: () => model.onSelect(suggestion),
        child: Padding(
          padding: const EdgeInsets.only(bottom: _kListItemMargin),
          child: AnimatedBuilder(
            animation: model.selection,
            builder: (context, child) {
              return Material(
                color: model.selection.value == index
                    ? Color(0xFFFF8BCB)
                    : Colors.white,
                elevation: model.elevation,
                child: child,
              );
            },
            child: Container(
              alignment: Alignment.centerLeft,
              height: _kListItemHeight,
              child: Text(
                suggestion.display.headline,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                textAlign: TextAlign.start,
                style: TextStyle(
                  color: Colors.black,
                  fontFamily: 'RobotoMono',
                  fontSize: 18.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
