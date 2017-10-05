// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/modular.dart';

import 'src/models/contact_list_model.dart';
import 'src/modular/contact_list_module_model.dart';
import 'src/widgets/contact_list.dart';

void main() {
  setupLogger(name: 'contacts/contact_list');

  // Tie the model to the UI
  ContactListModel model = new ContactListModel();
  ContactListModuleModel moduleModel = new ContactListModuleModel(model: model);

  ModuleWidget<ContactListModuleModel> moduleWidget =
      new ModuleWidget<ContactListModuleModel>(
    moduleModel: moduleModel,
    applicationContext: new ApplicationContext.fromStartupInfo(),
    child: new ScopedModel<ContactListModel>(
      model: model,
      child: const ContactList(),
    ),
  )..advertise();

  runApp(moduleWidget);
}
