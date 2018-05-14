// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:fidl/fidl.dart';

import 'package:lib.app.dart/app.dart';
import 'package:fidl_input/fidl.dart';

// ignore_for_file: public_member_api_docs

/// The current editor is a global, corresponding to the most recent one
/// connected.
_EditSession _currentSession;

/// A class representing an editing session.
class _EditSession {
  final InputMethodEditorClientProxy _client =
      new InputMethodEditorClientProxy();
  TextInputState _state;
  int _maxRev = 0;

  _EditSession(this._state);

  void init(InterfaceHandle<InputMethodEditorClient> clientHandle) {
    _client.ctrl.bind(clientHandle);
  }

  void close() {
    _client.ctrl.close();
  }

  void updateState(String text, TextSelection selection, TextRange composing,
      InputEvent event) {
    // increment to next odd revision
    int newRev = _maxRev + (_maxRev & 1) + 1;
    TextInputState newState = new TextInputState(
        revision: newRev,
        text: text,
        selection: selection,
        composing: composing);
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
      final KeyboardEvent kbEvent = event.keyboard;
      if (kbEvent.phase == KeyboardEventPhase.pressed &&
          kbEvent.codePoint != 0) {
        // TODO: handle combining characters
        String newChar = new String.fromCharCode(kbEvent.codePoint);
        int start = min(_state.selection.base, _state.selection.extent);
        int end = max(_state.selection.base, _state.selection.extent);
        String newText = _state.text.replaceRange(start, end, newChar);
        int cursor = start + newChar.length;
        TextSelection newSelection = new TextSelection(
            base: cursor, extent: cursor, affinity: TextAffinity.downstream);
        updateState(newText, newSelection, const TextRange(), event);
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

  void bind(InterfaceRequest<InputListener> request) {
    _binding.bind(this, request);
  }

  @override
  void onEvent(InputEvent event, void callback(bool consumed)) {
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
  void show() {}

  @override
  void hide() {}

  @override
  void setKeyboardType(KeyboardType keyboardType) {
    // nothing to do for hw kb
  }

  @override
  void injectInput(InputEvent event) {
    session.onEvent(event);
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
      InputMethodAction action,
      TextInputState initialState,
      InterfaceHandle<InputMethodEditorClient> client,
      InterfaceRequest<InputMethodEditor> editor) {
    // Shut down the old session; we only have one active at a time.
    _currentSession?.close();

    _EditSession session = new _EditSession(initialState)..init(client);
    // ignore: unused_local_variable
    InputMethodEditorImpl imeImpl = new InputMethodEditorImpl(session);
    _currentSession = session;
  }
}

void main(List<String> args) {
  ApplicationContext context = new ApplicationContext.fromStartupInfo();

  context.outgoingServices.addServiceForName(
    new ImeServiceImpl().bind,
    ImeService.$serviceName,
  );
}
