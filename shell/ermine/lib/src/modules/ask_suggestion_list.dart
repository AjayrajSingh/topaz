// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'ask_model.dart';

class AskSuggestionList extends StatelessWidget {
  final AskModel model;
  final _kListItemHeight = 50.0;
  final _kListVerticalPadding = 8.0;

  const AskSuggestionList({this.model});

  @override
  Widget build(BuildContext context) {
    final controller = ScrollController();
    model.selection.addListener(() {
      if (controller.hasClients && model.selection.value >= 0) {
        double itemOffset = model.selection.value * _kListItemHeight;
        if (itemOffset < controller.offset) {
          double scrollOffset = itemOffset;
          controller.animateTo(
            scrollOffset,
            duration: Duration(milliseconds: 200),
            curve: Curves.fastOutSlowIn,
          );
        } else if (itemOffset >=
            controller.offset +
                controller.position.viewportDimension -
                _kListItemHeight -
                _kListVerticalPadding) {
          double scrollOffset = (model.selection.value + 1) * _kListItemHeight -
              controller.position.viewportDimension;
          controller.animateTo(
            scrollOffset + _kListVerticalPadding,
            duration: Duration(milliseconds: 200),
            curve: Curves.fastOutSlowIn,
          );
        }
      }
    });
    return AnimatedBuilder(
      animation: model.suggestions,
      builder: (context, child) => Offstage(
            offstage: model.suggestions.value.isEmpty,
            child: Align(
              alignment: Alignment.topCenter,
              child: Material(
                elevation: model.elevation,
                color: Colors.white,
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  child: RawKeyboardListener(
                    onKey: model.onKey,
                    focusNode: model.focusNode,
                    child: ListView.builder(
                      controller: controller,
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: _kListVerticalPadding / 2,
                      ),
                      physics: BouncingScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: model.suggestions.value.length,
                      itemBuilder: (context, index) {
                        final suggestion = model.suggestions.value[index];
                        final iconImageNotifier =
                            model.imageFromSuggestion(suggestion);
                        return GestureDetector(
                          onTap: () => model.onSelect(suggestion),
                          child: AnimatedBuilder(
                            animation: model.selection,
                            builder: (context, child) {
                              return Container(
                                alignment: Alignment.centerLeft,
                                height: _kListItemHeight,
                                color: model.selection.value == index
                                    ? Colors.lightBlue
                                    : Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    AnimatedBuilder(
                                      animation: iconImageNotifier,
                                      builder: (context, child) => Offstage(
                                            offstage:
                                                iconImageNotifier.value == null,
                                            child: RawImage(
                                              color:
                                                  model.selection.value == index
                                                      ? Colors.white
                                                      : Colors.grey[900],
                                              image: iconImageNotifier.value,
                                              width: 24,
                                              height: 24,
                                              filterQuality:
                                                  FilterQuality.medium,
                                            ),
                                          ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(left: 8),
                                    ),
                                    Text(
                                      suggestion.display.headline,
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.fade,
                                      textAlign: TextAlign.start,
                                      style: TextStyle(
                                        color: model.selection.value == index
                                            ? Colors.white
                                            : Colors.grey[900],
                                        fontFamily: 'RobotoMono',
                                        fontWeight:
                                            model.selection.value == index
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                        fontSize: 22.0,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
    );
  }
}
