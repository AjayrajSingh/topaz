// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../blocs/app_bloc.dart';
import '../blocs/bloc_provider.dart';

class LaunchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bloc = BlocProvider.of<AppBloc>(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RaisedButton(
          child: Text('Launch Circle!'),
          onPressed: bloc.launchCircle,
        ),
        Padding(padding: EdgeInsets.all(8.0)),
        RaisedButton(
          child: Text('Launch Square!'),
          onPressed: bloc.launchSquare,
        ),
      ],
    );
  }
}
