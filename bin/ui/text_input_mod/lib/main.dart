// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:flutter/material.dart';
import 'package:fidl_fuchsia_textinputmod/fidl_async.dart';
import 'package:lib.app.dart/app_async.dart';

class ErmineTextInputMod extends TextInputMod {
  TextInputModReceiverProxy textInputModReceiverProxy;
  Completer completer;
  void sendData(String text) {
    if (completer != null) {
      textInputModReceiverProxy.userEnteredText(text).then((_) {
        completer.complete();
      });
    }
  }

  void cancel() {
    if (completer != null) {
      textInputModReceiverProxy.userCanceled().then((_) {
        completer.complete();
      });
    }
  }

  @override
  Future<void> listenForTextInput(
      InterfaceHandle<TextInputModReceiver> receiver) {
    textInputModReceiverProxy = TextInputModReceiverProxy();

    textInputModReceiverProxy.ctrl.bind(receiver);
    completer = Completer<void>();

    return completer.future;
  }
}

void main() {
  TextInputMod textInputMod = ErmineTextInputMod();

  StartupContext startupContext = StartupContext.fromStartupInfo();

  startupContext.outgoingServices.addServiceForName(
    (InterfaceRequest<TextInputMod> request) {
      TextInputModBinding().bind(textInputMod, request);
    },
    TextInputMod.$serviceName,
  );

  ValueNotifier<String> text = ValueNotifier('null');

  final FocusNode focusNode = FocusNode();

  runApp(MyApp(focusNode: focusNode, textInputMod: textInputMod, text: text));
}

class MyApp extends StatelessWidget {
  final FocusNode focusNode;
  final ErmineTextInputMod textInputMod;
  final ValueNotifier<String> text;

  /// Constructor
  const MyApp({
    @required this.focusNode,
    @required this.textInputMod,
    @required this.text,
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    FocusScope.of(context).requestFocus(
      focusNode,
    );
    return MaterialApp(
      title: 'text input',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        backgroundColor: Colors.blueGrey,
        body: Container(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(5),
                  child: IconButton(
                    icon: Icon(Icons.cancel),
                    iconSize: 30,
                    color: Colors.grey[100],
                    disabledColor: Colors.grey[500],
                    onPressed: textInputMod.cancel,
                  ),
                ),
                Flexible(
                  child: TextField(
                    focusNode: focusNode,
                    onChanged: (v) {
                      text.value = v;
                    },
                    onSubmitted: textInputMod.sendData,
                    decoration: InputDecoration(hintText: 'Enter Mod URL'),
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(5),
                  child: IconButton(
                    icon: Icon(Icons.send),
                    iconSize: 30,
                    color: Colors.grey[100],
                    disabledColor: Colors.grey[500],
                    onPressed: () {
                      textInputMod.sendData(text.value);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
