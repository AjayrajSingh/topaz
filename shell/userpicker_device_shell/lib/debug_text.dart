// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter/material.dart';

/// Displays debug text like hostname and ip addresses.
class DebugText extends StatefulWidget {
  @override
  _DebugTextState createState() => new _DebugTextState();
}

class _DebugTextState extends State<DebugText> {
  final List<InternetAddress> _addresses = <InternetAddress>[];
  @override
  void initState() {
    super.initState();

    /// TODO(apwilson): Reenable this code when it doesn't blow the app up.
    /*
    NetworkInterface.list().then((List<NetworkInterface> interfaces) {
      if (!mounted) {
        return;
      }
      setState(() {
        interfaces.forEach((NetworkInterface networkInterface) {
          _addresses.addAll(networkInterface.addresses);
        });
      });
    });
    */
  }

  @override
  Widget build(BuildContext context) {
    List<String> columnChildren = <String>[];
    columnChildren.addAll(
      _addresses.map((InternetAddress address) => address.address).toList(),
    );
    columnChildren.add(Platform.localHostname);
    return new Column(
        mainAxisSize: MainAxisSize.min,
        children: columnChildren
            .map(
              (String text) => new Container(
                    padding: const EdgeInsets.all(12.0),
                    color: Colors.black54,
                    child: new Text(
                      text,
                      style: new TextStyle(
                        fontFamily: 'RobotoMono',
                        color: Colors.white,
                      ),
                    ),
                  ),
            )
            .toList());
  }
}
