// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show RawKeyDownEvent, RawKeyEventDataFuchsia;

import 'package:fidl/fidl.dart' show InterfaceRequest;
import 'package:fidl_fuchsia_modular/fidl_async.dart'
    show
        Interaction,
        InteractionType,
        QueryListener,
        QueryListenerBinding,
        Suggestion,
        SuggestionProviderProxy,
        UserInput;
import 'package:fidl_fuchsia_shell_ermine/fidl_async.dart'
    show AskBar, AskBarBinding;
import 'package:fuchsia_services/services.dart'
    show connectToEnvironmentService, StartupContext;
import 'package:lib.widgets/model.dart' show SpringModel;
import 'package:zircon/zircon.dart' show Vmo;

const int _kMaxSuggestions = 20;

// Keyboard HID usage values defined in:
// https://www.usb.org/sites/default/files/documents/hut1_12v2.pdf
const int _kUpArrow = 82;
const int _kDownArrow = 81;
const int _kPageDown = 78;
const int _kPageUp = 75;
const int _kEsc = 41;

class AskModel extends ChangeNotifier {
  final StartupContext startupContext;
  final TextEditingController controller = TextEditingController();
  final FocusNode focusNode = FocusNode();
  final ValueNotifier<bool> visibility = ValueNotifier(false);
  final ValueNotifier<List<Suggestion>> suggestions =
      ValueNotifier(<Suggestion>[]);
  final ValueNotifier<int> selection = ValueNotifier(-1);
  final SpringModel animation = SpringModel();

  double autoCompleteTop = 0;
  double elevation = 200.0;

  _AskImpl _ask;

  final _askBinding = AskBarBinding();
  final _suggestionProvider = SuggestionProviderProxy();

  // Holds the suggestion results until query completes.
  List<Suggestion> _suggestions = <Suggestion>[];

  AskModel({this.startupContext}) {
    _ask = _AskImpl(this);
    connectToEnvironmentService(_suggestionProvider);
  }

  void focus(BuildContext context) =>
      FocusScope.of(context).requestFocus(focusNode);

  void unfocus() => focusNode.unfocus();

  bool get isVisible => visibility.value;

  ValueNotifier<ui.Image> imageFromSuggestion(Suggestion suggestion) {
    final image = ValueNotifier<ui.Image>(null);
    if (suggestion?.display?.icons?.first?.image?.vmo != null) {
      final vmo = suggestion.display.icons.first.image.vmo;
      _imageFromVmo(vmo).then((img) => image.value = img);
    }
    return image;
  }

  Future<ui.Image> _imageFromVmo(Vmo vmo) async {
    final bytes = vmo.read(vmo.getSize().size).bytesAsUint8List();
    final codec = await ui.instantiateImageCodec(bytes);
    final frameInfo = await codec.getNextFrame();
    final image = frameInfo.image;
    codec.dispose();
    return image;
  }

  // ignore: use_setters_to_change_properties
  void load(double elevation) {
    this.elevation = elevation;
  }

  void show() {
    visibility.value = true;
    _ask.fireVisible();
    animation
      ..jump(0.8)
      ..target = 1.0;
    controller.clear();
  }

  void hide() {
    _suggestions = <Suggestion>[];
    suggestions.value = _suggestions;
    selection.value = -1;
    _ask.fireHidden();
    visibility.value = false;
    animation.jump(0.8);
    controller.clear();
  }

  void onAsk(String query) {
    // If there are no suggestions, do nothing.
    if (suggestions.value.isEmpty) {
      return;
    }
    // Use the top suggestion (highest confidence) if user did not select
    // another suggestion from the list.
    if (selection.value < 0) {
      onSelect(suggestions.value.first);
    } else {
      onSelect(suggestions.value[selection.value]);
    }
  }

  void onKey(RawKeyEvent event) {
    RawKeyEventDataFuchsia data = event.data;
    // We only process pure key down events: codePoint = 0 and modifiers = 0.
    int newSelection = selection.value;
    if (event is RawKeyDownEvent &&
        suggestions.value.isNotEmpty &&
        data.codePoint == 0 &&
        data.modifiers == 0) {
      switch (data.hidUsage) {
        case _kEsc:
          hide();
          return;
        case _kDownArrow:
          newSelection++;
          break;
        case _kUpArrow:
          newSelection--;
          break;
        case _kPageDown:
          newSelection += 5;
          break;
        case _kPageUp:
          newSelection -= 5;
          break;
        default:
          return;
      }
      selection.value = newSelection.clamp(0, suggestions.value.length - 1);
      controller
        ..text = suggestions.value[selection.value].display.details
        ..selection = TextSelection.fromPosition(TextPosition(
          offset: controller.text.length,
        ));
    }
  }

  void onQuery(String query) {
    if (query?.isEmpty ?? true) {
      return;
    }

    _suggestions = <Suggestion>[];

    final queryListenerBinding = QueryListenerBinding();
    _suggestionProvider.query(
      queryListenerBinding.wrap(_QueryListenerImpl(this)),
      UserInput(text: query),
      _kMaxSuggestions,
    );
  }

  void onSelect(Suggestion suggestion) {
    _suggestionProvider.notifyInteraction(
      suggestion.uuid,
      Interaction(type: InteractionType.selected),
    );
    hide();
  }

  void advertise() {
    startupContext.outgoing.addServiceForName(
      (InterfaceRequest<AskBar> request) => _askBinding.bind(_ask, request),
      AskBar.$serviceName,
    );
  }

  /// QueryListener.
  void onQueryComplete() {
    // Display suggestion list if Ask bar is still visible.
    if (visibility.value) {
      selection.value = -1;
      suggestions.value = _suggestions;
    }
  }

  // ignore: use_setters_to_change_properties
  /// QueryListener.
  void onQueryResults(List<Suggestion> suggestions) {
    // Hold onto the suggestion in _suggestions until onQueryComplete is
    // called.
    _suggestions = suggestions;
  }
}

class _AskImpl extends AskBar {
  final AskModel askModel;
  final _onHiddenStream = StreamController<void>();
  final _onVisibleStream = StreamController<void>();

  _AskImpl(this.askModel);

  void close() {
    _onHiddenStream.close();
    _onVisibleStream.close();
  }

  void fireHidden() => _onHiddenStream.add(null);

  void fireVisible() => _onVisibleStream.add(null);

  @override
  Future<void> show() async => askModel.show();

  @override
  Future<void> hide() async => askModel.hide();

  @override
  Future<void> load(double elevation) async => askModel.load(elevation);

  @override
  Stream<void> get onHidden => _onHiddenStream.stream;

  @override
  Stream<void> get onVisible => _onVisibleStream.stream;
}

class _QueryListenerImpl extends QueryListener {
  final AskModel askModel;

  _QueryListenerImpl(this.askModel);

  @override
  Future<void> onQueryComplete() async => askModel.onQueryComplete();

  @override
  Future<void> onQueryResults(List<Suggestion> suggestions) async =>
      askModel.onQueryResults(suggestions);
}
