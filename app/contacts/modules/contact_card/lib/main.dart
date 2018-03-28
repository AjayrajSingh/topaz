// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';
import 'package:lib.schemas.dart/com.fuchsia.contact.dart';

import 'src/models/contact_card_model.dart';
import 'src/widgets/contact_card.dart';

void main() {
  setupLogger(name: 'contacts/card');

  ContactCardModel model = new ContactCardModel();
  ContactEntityCodec codec = new ContactEntityCodec();

  new ModuleDriver()
    ..watch('contact', codec).listen(
      (ContactEntityData entity) => model.contact = entity,
      onError: (Object err, StackTrace stackTrace) {
        model.error = true;
        log.warning('$err: $stackTrace');
      },
    )
    ..start().then((_) {
      log.fine('Contacts card starting');
    });

  runApp(
    new MaterialApp(
      home: new Scaffold(
        body: new ScopedModel<ContactCardModel>(
          model: model,
          child: new ContactCard(),
        ),
      ),
    ),
  );
}
