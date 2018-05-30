// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app.dart/app.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fidl/fidl.dart';
import 'package:meta/meta.dart';

import '../widgets/window_media_query.dart';
import 'module_impl.dart';
import 'module_model.dart';

/// A wrapper widget intended to be the root of the application that is a
/// Module. Its main purpose is to hold the [ApplicationContext] and
/// [ModuleImpl] instances so they aren't garbage collected. For convenience,
/// [advertise] does the advertising of the app as a Module to the rest of the
/// system via the [ApplicationContext]. Also for convienence, the [ModuleModel]
/// given to this widget will be made available to [child] and [child]'s
/// descendants.
class ModuleWidget<T extends ModuleModel> extends StatelessWidget {
  /// The binding for the [Lifecycle] service implemented by [ModuleImpl].
  final LifecycleBinding _lifecycleBinding;

  /// The [ModuleImpl] whose services to [advertise].
  final ModuleImpl _module;

  /// The [ApplicationContext] to [advertise] its Module services to.
  final ApplicationContext applicationContext;

  /// The [ModuleModel] to notify when the Module is ready.
  final T _moduleModel;

  /// The rest of the application.
  final Widget child;

  /// Constructor.
  factory ModuleWidget({
    @required ApplicationContext applicationContext,
    @required T moduleModel,
    @required Widget child,
  }) =>
      new ModuleWidget<T>._create(
        applicationContext: applicationContext,
        moduleModel: moduleModel,
        child: child,
        lifecycleBinding: new LifecycleBinding(),
      );

  ModuleWidget._create({
    @required this.applicationContext,
    @required T moduleModel,
    @required this.child,
    @required LifecycleBinding lifecycleBinding,
  })
      : _moduleModel = moduleModel,
        _lifecycleBinding = lifecycleBinding,
        _module = new ModuleImpl(
          applicationContext: applicationContext,
          onReady: moduleModel?.onReady,
          onStopping: moduleModel?.onStop,
          onStop: () {
            lifecycleBinding.close();
          },
          onNotify: moduleModel?.onNotify,
          onDeviceMapChange: moduleModel?.onDeviceMapChange,
          watchAll: moduleModel?.watchAll,
        );

  @override
  Widget build(BuildContext context) => new MaterialApp(
        home: new Material(
          child: new Directionality(
            textDirection: TextDirection.ltr,
            child: new WindowMediaQuery(
              child: _moduleModel == null
                  ? child
                  : new ScopedModel<T>(
                      model: _moduleModel,
                      child: child,
                    ),
            ),
          ),
        ),
      );

  /// Advertises [_module] as a Module to the rest of the system via the
  /// [applicationContext].
  void advertise() {
    applicationContext.outgoingServices
      .addServiceForName(
        (InterfaceRequest<Lifecycle> request) =>
            _lifecycleBinding.bind(_module, request),
        Lifecycle.$serviceName,
      );
  }
}
