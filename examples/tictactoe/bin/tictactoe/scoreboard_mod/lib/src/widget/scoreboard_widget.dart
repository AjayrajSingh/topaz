import 'package:flutter/material.dart';
import 'package:lib.widgets/modular.dart';

import '../model/scoreboard_model.dart';

class ScoreBoardWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new ScopedModelDescendant<ScoreBoardModel>(
      builder: (content, child, model) {
        return new Text(
          'X: ${model.xScore}   O: ${model.oScore}',
          style: new TextStyle(fontSize: 30.0, color: Colors.black),
        );
      },
    );
  }
}
