import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';

import 'start_module_button.dart';

/// Specify an emphasis and launch a copresented surface
class CopresentLauncher extends StatefulWidget {
  final ModuleContext _moduleContext;

  final GenerateChildId _generateChildId;

  /// CopresentLauncher
  const CopresentLauncher(this._moduleContext, this._generateChildId, {Key key})
      : super(key: key);

  @override
  CopresentLauncherState createState() =>
      new CopresentLauncherState(_moduleContext, _generateChildId);
}

/// Copresent Launch State
class CopresentLauncherState extends State<CopresentLauncher> {
  final ModuleContext _moduleContext;

  final GenerateChildId _generateChildId;

  CopresentLauncherState(
    this._moduleContext,
    this._generateChildId,
  ) : super();

  double _copresentEmphasisExp = 0.0;

  double get _emphasis =>
      (math.pow(2, _copresentEmphasisExp) * 10.0).roundToDouble() / 10.0;

  @override
  Widget build(BuildContext context) => new Container(
        alignment: FractionalOffset.center,
        constraints: const BoxConstraints(maxWidth: 200.0),
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            new Slider(
              min: -1.6,
              max: 1.6,
              value: _copresentEmphasisExp,
              label: 'Emphasis: $_emphasis',
              onChanged: (double value) =>
                  setState(() => _copresentEmphasisExp = value),
            ),
            new StartModuleButton(
              _moduleContext,
              new SurfaceRelation(
                emphasis: _emphasis,
                arrangement: SurfaceArrangement.copresent,
              ),
              'Copresent',
              _generateChildId,
            ),
            new StartModuleButton(
              _moduleContext,
              new SurfaceRelation(
                emphasis: _emphasis,
                arrangement: SurfaceArrangement.copresent,
                dependency: SurfaceDependency.dependent,
              ),
              'Dependent\nCopresent',
              _generateChildId,
            ),
          ],
        ),
      );
}
