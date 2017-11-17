// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

import 'src/models/contact_card_model.dart';
import 'src/modular/contact_card_module_model.dart';
import 'src/widgets/contact_card.dart';

void main() {
  setupLogger(name: 'contacts/card');

  ContactCardModel model = new ContactCardModel();
  ContactCardModuleModel moduleModel = new ContactCardModuleModel(model: model);
  ModuleWidget<ContactCardModuleModel> moduleWidget =
      new ModuleWidget<ContactCardModuleModel>(
    moduleModel: moduleModel,
    applicationContext: new ApplicationContext.fromStartupInfo(),
    child: new ScopedModel<ContactCardModel>(
      model: model,
      child: new MaterialApp(
        home: new Scaffold(
          body: new ContactCard(),
        ),
      ),
    ),
  )..advertise();

  runApp(moduleWidget);
}
