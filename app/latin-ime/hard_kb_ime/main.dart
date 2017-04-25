// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:lib.fidl.dart/bindings.dart';

import 'package:application.lib.app.dart/app.dart';
import 'package:apps.mozart.services.input/ime_service.fidl.dart';
import 'package:apps.mozart.services.input/input_connection.fidl.dart';
import 'package:apps.mozart.services.input/input_events.fidl.dart';
import 'package:apps.mozart.services.input/text_editing.fidl.dart';
import 'package:apps.mozart.services.input/text_input.fidl.dart';

final ApplicationContext _context = new ApplicationContext.fromStartupInfo();

/// The current editor is a global, corresponding to the most recent one
/// connected.
_EditSession _currentSession;

/// A class representing an editing session.
class _EditSession {
  InputMethodEditorClient _client = new InputMethodEditorClientProxy();
  TextInputState _state;
  int _maxRev = 0;

  _EditSession(this._state);

  void init(InterfaceHandle<InputMethodEditorClient> clientHandle) {
    _client.ctrl.bind(clientHandle);
  }

  void updateState(String text, TextSelection selection, TextRange composing,
    InputEvent event) {
    // increment to next odd revision
    int newRev = _maxRev + (_maxRev & 1) + 1;
    TextInputState newState = new TextInputState.init(newRev, text, selection, composing);
    _maxRev = newRev;
    _state = newState;
    _client.didUpdateState(newState, event);
  }

  void setState(TextInputState state) {
    _maxRev = max(_maxRev, state.revision);
    _state = state;
    // TODO: do we want to ack?
  }

  bool onEvent(InputEvent event) {
    if (event.tag == InputEventTag.keyboard) {
      final kbEvent = event.keyboard;
      if (kbEvent.phase == KeyboardEventPhase.pressed && kbEvent.codePoint != 0) {
        // TODO: handle combining characters
        String newChar = new String.fromCharCode(kbEvent.codePoint);
        int start = min(_state.selection.baseOffset, _state.selection.extentOffset);
        int end = max(_state.selection.baseOffset, _state.selection.extentOffset);
        String newText = _state.text.replaceRange(start, end, newChar);
        int cursor = start + newChar.length;
        TextSelection newSelection = new TextSelection.init(
          cursor, cursor, cursor, cursor, TextAffinity.downstream);
        updateState(newText, newSelection, new TextRange(), event);
        return true;
      }
      // TODO: handle editing commands other than inserting keys (backspace etc)
    }
    return false;
  }
}

/// The InputListener we use to receive raw keyboard events
class InputListenerImpl extends InputListener {
  final InputListenerBinding _binding = new InputListenerBinding();

  void bind(InterfaceRequest<InputListener > request) {
    _binding.bind(this, request);
  }

  @override
  onEvent(InputEvent event, void callback(bool consumed)) {
    callback(_currentSession?.onEvent(event));
  }
}

class InputMethodEditorImpl extends InputMethodEditor {
  final InputMethodEditorBinding _binding = new InputMethodEditorBinding();
  _EditSession session;

  InputMethodEditorImpl(this.session);

  void bind(InterfaceRequest<InputMethodEditor> request) {
    _binding.bind(this, request);
  }

  @override
  void setKeyboardType(KeyboardType keyboard_type) {
    // nothing to do for hw kb
  }

  @override
  void setState(TextInputState state) {
    session.setState(state);
  }
}

class ImeServiceImpl extends ImeService {
  final ImeServiceBinding _binding = new ImeServiceBinding();

  void bind(InterfaceRequest<ImeService> request) {
    _binding.bind(this, request);
  }

  @override
  void getInputMethodEditor(
    KeyboardType keyboardType,
    TextInputState initialState,
    InterfaceHandle<InputMethodEditorClient> client,
    InterfaceRequest<InputMethodEditor> session
  ) {
    // Shut down the old session; we only have one active at a time.
    _currentSession?.ctrl?.close();

    _EditSession session = new _EditSession(initialState);
    session.init(client);
    InputMethodEditorImpl imeImpl = new InputMethodEditorImpl(session);
    _currentSession = session;
  }

  @override
  void injectInput(InputEvent event) {
    _currentSession?.onEvent(event);
  }
}

void main(List args) {
  ApplicationContext context = new ApplicationContext.fromStartupInfo();

  context.outgoingServices.addServiceForName((request) {
    new ImeServiceImpl().bind(request);
  }, ImeService.serviceName);
}
