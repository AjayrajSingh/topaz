// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:flutter/material.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';
import 'package:widgets/hotel.dart';

import 'src/hotel_confirmation_module_model.dart';

/// Main entry point to the Hotel Confirmation Module
void main() {
  setupLogger(name: 'Hotel Confirmation Module');

  ApplicationContext applicationContext =
      new ApplicationContext.fromStartupInfo();

  HotelConfirmationModuleModel hotelModuleModel =
      new HotelConfirmationModuleModel();

  ModuleWidget<HotelConfirmationModuleModel> moduleWidget =
      new ModuleWidget<HotelConfirmationModuleModel>(
    applicationContext: applicationContext,
    moduleModel: hotelModuleModel,
    child: new Scaffold(
      body: new ScopedModelDescendant<HotelConfirmationModuleModel>(builder: (
        BuildContext context,
        Widget child,
        HotelConfirmationModuleModel model,
      ) {
        return new SingleChildScrollView(
          child: new Center(
            child: new Confirmation(
              onTapManageBooking: model.manageBooking,
            ),
          ),
        );
      }),
    ),
  );

  runApp(moduleWidget);
  moduleWidget.advertise();
}
