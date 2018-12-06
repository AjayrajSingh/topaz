// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_cobalt/fidl.dart' as cobalt;
import 'package:fidl_fuchsia_mem/fidl.dart';
import 'package:fidl_fuchsia_netstack/fidl.dart';
import 'package:flutter/material.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.base_shell/netstack_model.dart';
import 'package:lib.widgets/application.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/modular.dart';
import 'package:meta/meta.dart';
import 'package:zircon/zircon.dart';

import 'authentication_overlay.dart';
import 'authentication_overlay_model.dart';
import 'authentication_ui_context_impl.dart';
import 'user_picker_base_shell_model.dart';
import 'user_picker_base_shell_screen.dart';

const double _kMousePointerElevation = 800.0;
const double _kIndicatorElevation = _kMousePointerElevation - 1.0;

const String _kCobaltConfigBinProtoPath = '/pkg/data/sysui_metrics_config.pb';

/// The main base shell widget.
BaseShellWidget<UserPickerBaseShellModel> _baseShellWidget;

void main() {
  setupLogger(name: 'userpicker_base_shell');
  trace('starting');
  StartupContext startupContext = new StartupContext.fromStartupInfo();

  // Connect to Cobalt
  cobalt.LoggerProxy logger = new cobalt.LoggerProxy();

  cobalt.LoggerFactoryProxy loggerFactory = new cobalt.LoggerFactoryProxy();
  connectToService(startupContext.environmentServices, loggerFactory.ctrl);

  SizedVmo configVmo = SizedVmo.fromFile(_kCobaltConfigBinProtoPath);
  cobalt.ProjectProfile profile = cobalt.ProjectProfile(
      config: Buffer(vmo: configVmo, size: configVmo.size),
      releaseStage: cobalt.ReleaseStage.ga);
  loggerFactory.createLogger(profile, logger.ctrl.request(), (cobalt.Status s) {
    if (s != cobalt.Status.ok) {
      print('Failed to obtain Logger. Cobalt config is invalid.');
    }
  });
  loggerFactory.ctrl.close();

  NetstackProxy netstackProxy = new NetstackProxy();
  connectToService(startupContext.environmentServices, netstackProxy.ctrl);

  NetstackModel netstackModel = new NetstackModel(netstack: netstackProxy)
    ..start();

  _OverlayModel wifiInfoOverlayModel = new _OverlayModel();

  final AuthenticationOverlayModel authModel = AuthenticationOverlayModel();

  UserPickerBaseShellModel userPickerBaseShellModel =
      new UserPickerBaseShellModel(
    onBaseShellStopped: () {
      netstackProxy.ctrl.close();
      netstackModel.dispose();
    },
    onLogin: () {
      wifiInfoOverlayModel.showing = false;
    },
    onWifiTapped: () {
      wifiInfoOverlayModel.showing = !wifiInfoOverlayModel.showing;
    },
    logger: logger,
  );

  Widget mainWidget = new Stack(
    fit: StackFit.passthrough,
    children: <Widget>[
      new UserPickerBaseShellScreen(
        launcher: startupContext.launcher,
      ),
      new ScopedModel<AuthenticationOverlayModel>(
        model: authModel,
        child: AuthenticationOverlay(),
      ),
    ],
  );

  Widget app = mainWidget;

  List<OverlayEntry> overlays = <OverlayEntry>[
    new OverlayEntry(
      builder: (BuildContext context) => new MediaQuery(
            data: const MediaQueryData(),
            child: new FocusScope(
              node: new FocusScopeNode(),
              autofocus: true,
              child: app,
            ),
          ),
    ),
    new OverlayEntry(
      builder: (BuildContext context) => new ScopedModel<_OverlayModel>(
            model: wifiInfoOverlayModel,
            child: new _WifiInfo(
              wifiWidget: new ApplicationWidget(
                url: 'fuchsia-pkg://fuchsia.com/wifi_settings#meta/wifi_settings.cmx',
                launcher: startupContext.launcher,
              ),
            ),
          ),
    ),
  ];

  _baseShellWidget = new BaseShellWidget<UserPickerBaseShellModel>(
    startupContext: startupContext,
    baseShellModel: userPickerBaseShellModel,
    authenticationUiContext: new AuthenticationUiContextImpl(
        onStartOverlay: authModel.onStartOverlay,
        onStopOverlay: authModel.onStopOverlay),
    child: new LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          (constraints.biggest == Size.zero)
              ? const Offstage()
              : new ScopedModel<NetstackModel>(
                  model: netstackModel,
                  child: new Overlay(initialEntries: overlays),
                ),
    ),
  );

  runApp(_baseShellWidget);

  _baseShellWidget.advertise();
  trace('started');
}

class _WifiInfo extends StatelessWidget {
  final Widget wifiWidget;

  const _WifiInfo({@required this.wifiWidget}) : assert(wifiWidget != null);

  @override
  Widget build(BuildContext context) =>
      new ScopedModelDescendant<_OverlayModel>(
        builder: (
          BuildContext context,
          Widget child,
          _OverlayModel model,
        ) =>
            new Offstage(
              offstage: !model.showing,
              child: new Stack(
                children: <Widget>[
                  new Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (PointerDownEvent event) {
                      model.showing = false;
                    },
                  ),
                  new Center(
                    child: new FractionallySizedBox(
                      widthFactor: 0.75,
                      heightFactor: 0.75,
                      child: new Container(
                        margin: const EdgeInsets.all(8.0),
                        child: new PhysicalModel(
                          color: Colors.grey[900],
                          elevation: _kIndicatorElevation,
                          borderRadius: new BorderRadius.circular(8.0),
                          child: wifiWidget,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      );
}

class _OverlayModel extends Model {
  bool _showing = false;

  set showing(bool showing) {
    if (_showing != showing) {
      _showing = showing;
      notifyListeners();
    }
  }

  bool get showing => _showing;
}
