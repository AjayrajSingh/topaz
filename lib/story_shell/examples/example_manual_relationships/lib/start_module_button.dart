import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fuchsia_modular/module.dart';
import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl_mod;
import 'package:fuchsia_logger/logger.dart';

const String _kModuleUrl =
    'fuchsia-pkg://fuchsia.com/example_manual_relationships#meta/example_manual_relationships.cmx';

typedef GenerateChildId = String Function();

/// Button widget to start a module
class StartModuleButton extends StatelessWidget {
  /// The relationship to introduce a new surface with
  final fidl_mod.SurfaceRelation _relation;

  /// The display text for the relationship
  final String _display;

  /// A fuction used to generate a child id
  final GenerateChildId _generateChildId;

  /// Construct a button [Widget] to add new surface with given relationship
  const StartModuleButton(this._relation, this._display, this._generateChildId);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: RaisedButton(
        child: Center(
          child: Text(_display),
        ),
        onPressed: () {
          log.fine('starting module with relation $_relation');
          _startChildModule(_relation).catchError((e) {
            Scaffold.of(context).showSnackBar(
                SnackBar(content: Text('Failed to start Module, see syslog')));
            log.warning('Failed to start child module', e);
          });
        },
      ),
    );
  }

  /// Starts a new module and returns its controller
  Future<fidl_mod.ModuleControllerProxy> _startChildModule(
      fidl_mod.SurfaceRelation relation) {
    String name = _generateChildId();

    final intent = Intent(action: '', handler: _kModuleUrl);
    return Module().addModuleToStory(
      name: name,
      intent: intent,
      surfaceRelation: relation,
    );
  }
}
