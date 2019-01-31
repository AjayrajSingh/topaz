import 'package:flutter/material.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:lib.module_resolver.dart/intent_builder.dart';

const String _kModuleUrl =
    'fuchsia-pkg://fuchsia.com/example_manual_relationships#meta/example_manual_relationships.cmx';

typedef GenerateChildId = String Function();

/// Button widget to start a module
class StartModuleButton extends StatelessWidget {
  final ModuleContext _moduleContext;

  /// The relationship to introduce a new surface with
  final SurfaceRelation _relation;

  /// The display text for the relationship
  final String _display;

  /// A fuction used to generate a child id
  final GenerateChildId _generateChildId;

  /// Construct a button [Widget] to add new surface with given relationship
  const StartModuleButton(this._moduleContext, this._relation, this._display,
      this._generateChildId);

  @override
  Widget build(BuildContext context) {
    return new Padding(
      padding: const EdgeInsets.all(16.0),
      child: new RaisedButton(
        child: new Center(
          child: new Text(_display),
        ),
        onPressed: () {
          print(
              'starting module with relation $_relation moduleContext $_moduleContext');
          startChildModule(_moduleContext, _relation);
        },
      ),
    );
  }

  /// Starts a new module and returns its controller
  ModuleController startChildModule(
      ModuleContext moduleContext, SurfaceRelation relation) {
    ModuleControllerProxy moduleController = new ModuleControllerProxy();

    String name = _generateChildId();

    IntentBuilder intentBuilder = new IntentBuilder.handler(_kModuleUrl);
    moduleContext.addModuleToStory(
        name,
        intentBuilder.intent,
        moduleController.ctrl.request(),
        relation,
        (StartModuleStatus status) {});
    return moduleController;
  }
}
