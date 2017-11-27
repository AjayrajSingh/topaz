// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app.dart/app.dart';
import 'package:flutter/material.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

import 'src/modular/contacts_picker_module_model.dart';
import 'src/widgets/contacts_picker.dart';

/*
  This Module will experiment with the use of the Flutter Flux framework.
  It will be compared to the Contact_List module which also follows a flux-like
  pattern along the lines of unidirectional data flow.
*/
void main() {
  setupLogger(name: 'contacts/contacts_picker');

  ContactsPickerModuleModel moduleModel = new ContactsPickerModuleModel();
  ModuleWidget<ContactsPickerModuleModel> moduleWidget =
      new ModuleWidget<ContactsPickerModuleModel>(
    moduleModel: moduleModel,
    applicationContext: new ApplicationContext.fromStartupInfo(),
    child: new MaterialApp(
      title: 'Contacts Picker',
      theme: new ThemeData(primarySwatch: Colors.blue),
      home: new ContactsPicker(),
    ),
  )..advertise();

  runApp(moduleWidget);
}
