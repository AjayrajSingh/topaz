// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:fuchsia_scenic_flutter/child_view.dart' show ChildView;

import '../models/story_manager.dart';

class Stories extends StatelessWidget {
  final StoryManager storyManager;
  final double elevation;
  final ValueChanged<int> onChangeStory;

  const Stories({
    this.storyManager,
    this.elevation,
    this.onChangeStory,
  });

  @override
  Widget build(BuildContext context) {
    final controller = PageController();
    storyManager.addListener(() {
      int index = storyManager.focusedStoryIndex;
      if (index < 0) {
        return;
      }
      // The first list item is empty.
      index++;
      controller.animateToPage(
        index,
        duration: Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
    return AnimatedBuilder(
      animation: storyManager,
      builder: (BuildContext context, Widget child) {
        final stories = storyManager.stories;
        return PageView.builder(
          controller: controller,
          scrollDirection: Axis.horizontal,
          itemCount: stories.length + 1,
          onPageChanged: (index) {
            onChangeStory(index);
            storyManager.onChangeFocus(index);
          },
          itemBuilder: (context, index) {
            final story = index == 0 ? null : stories.elementAt(index - 1);
            return Container(
              padding: EdgeInsets.all(32),
              child: index == 0
                  ? null
                  : Material(
                      elevation: elevation,
                      borderRadius: BorderRadius.zero,
                      color: Colors.grey,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            height: 18,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                children: <Widget>[
                                  Text(
                                    story.storyInfo.id ?? story.storyInfo.url,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Spacer(flex: 1),
                                  IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    padding: EdgeInsets.all(0),
                                    onPressed: story.onClose,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 18,
                            left: 2,
                            right: 2,
                            bottom: 2,
                            child: GestureDetector(
                              // Disable listview scrolling on top of story.
                              onHorizontalDragStart: (_) {},
                              child: ChildView(
                                connection: story.childViewConnection,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            );
          },
        );
      },
    );
  }
}
