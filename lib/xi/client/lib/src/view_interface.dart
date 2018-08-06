// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

/// An interface for types that manage a particular xi view.
abstract class XiViewProxy {
  /// Insert `text` at the current cursor positions.
  void insert(String text);

  /// Insert a newline at the current cursor positions.
  void insertNewline();

  /// Insert a tab (or alternative whitespace) at the current cursor positions.
  void insertTab();

  /// The cancel action clears find state.
  void cancel();

  /// Notify core of a scroll event. `first` and `last` refer to lines visible
  /// in the new scroll region.
  void scroll(int first, int last);

  /// Notify core of a change in the size of the view. `width` and `height` are in
  /// logical points.
  void resize(int width, int height);

  /// Perform the given [GestureType] at the (utf-8 indexed) line and column.
  void gesture(int line, int col, GestureType type);

  /// Updates the drag state. This updates selections. A drag is implicitly started
  /// when any gesture occurs that modifies the selection.
  void drag(int line, int col);

  /// Move the active cursors by the [Movement].
  void moveCursor(Movement movement);

  /// Move the active cursors by the [Movement], modifying the existing selection.
  void moveCursorModifyingSelection(Movement movement);

  /// Moves the viewport without modifying the selection.
  void scrollPageUp();

  /// Moves the viewport without modifying the selection.
  void scrollPageDown();

  /// Cut the currently selected text.
  Future<String> cut();

  /// Copy the currently selected text.
  Future<String> copy();

  //NOTE: unclear that kill & yank should be supported on fuchsia.

  /// Deletes to the end of the current line, saving to the internal killring.
  void kill();

  /// Inserts the contents of the kill ring at the current cursor.
  void yank();

  /// Undos the most recent group of changes.
  void undo();

  /// Reverts the most recent undo.
  void redo();

  /// Notifies core that the frontend would like to receive the lines
  /// in the range (first, last]. These will be returned via the normal
  /// `update` method.
  void requestLines(int first, int last);

  /// Deletes the selected region, if any, or backwards one deletion unit
  /// from a caret.
  void deleteBackward();

  /// Deletes the selected region, if any, or forwards one deletion unit
  /// from the caret.
  void deleteForward();

  // Commands that modify the selected text

  /// Uppercases the selected text. 'Uppercase' is defined according to the
  /// Unicode Derived Core Property of that name.
  void uppercase();

  /// Lowercases the selected text. 'Lowercase' is defined according to the
  /// Unicode Derived Core Property of that name.
  void lowercase();

  /// Increases the indentation of the selected text by one level.
  void indent();

  /// Decreases the indentation of the selected text by one level.
  void outdent();

  /// If the selection is a caret, swaps the character before the caret
  /// with the character after the caret, advancing the cursor.
  /// If the selection is a region, and there are multiple regions, rotates them;
  /// That is, if regions ordered A, B, C are selected, `transpose` produces
  /// regions C, A, B.
  void transpose();
}

/// Gesture types recognized by core. These can map to different gestures or
/// mouse events on different platforms.
enum GestureType {
  // moves the cursor to a point
  pointSelect,
  // adds or removes a selection at a point
  toggleSel,
  // modifies the selection to include a point (shift+click)
  rangeSelect,
  // sets the selection to a given line
  lineSelect,
  // sets the selection to a given word
  wordSelect,
  // adds a line to the selection
  multiLineSelect,
  // adds a word to the selection
  multiWordSelect,
}

/// Movement types recognized by core. These are used to place the cursor.
enum Movement {
  up,
  down,
  left,
  right,
  wordLeft,
  wordRight,
  leftEndOfLine,
  rightEndOfLine,
  beginningOfParagraph,
  endOfParagraph,
  pageUp,
  pageDown,
  beginningOfDocument,
  endOfDocument,
}

String gestureToString(GestureType gesture) {
  switch (gesture) {
    case GestureType.pointSelect:
      return 'point_select';
    case GestureType.toggleSel:
      return 'toggle_sel';
    case GestureType.rangeSelect:
      return 'range_select';
    case GestureType.lineSelect:
      return 'line_select';
    case GestureType.wordSelect:
      return 'word_select';
    case GestureType.multiLineSelect:
      return 'multi_line_select';
    case GestureType.multiWordSelect:
      return 'multi_word_select';
  }
  assert(false, 'unreachable');
  return 'GestureType enum case not handled';
}

String movementToString(Movement movement) {
  switch (movement) {
    case Movement.left:
      return 'move_left';
    case Movement.right:
      return 'move_right';
    case Movement.down:
      return 'move_down';
    case Movement.up:
      return 'move_up';
    case Movement.wordLeft:
      return 'move_word_left';
    case Movement.wordRight:
      return 'move_word_right';
    case Movement.leftEndOfLine:
      return 'move_to_left_end_of_line';
    case Movement.rightEndOfLine:
      return 'move_to_right_end_of_line';
    case Movement.beginningOfParagraph:
      return 'move_to_beginning_of_paragraph';
    case Movement.endOfParagraph:
      return 'move_to_end_of_paragraph';
    case Movement.beginningOfDocument:
      return 'move_to_beginning_of_document';
    case Movement.endOfDocument:
      return 'move_to_end_of_document';
    case Movement.pageDown:
      return 'page_down';
    case Movement.pageUp:
      return 'page_up';
  }
  assert(false, 'unreachable');
  return 'Movement enum case not handled';
}
