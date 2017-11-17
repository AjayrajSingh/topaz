// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:entity_schemas/entities.dart' as entities;
import 'package:lib.widgets/model.dart';

/// The [ContactCardModel] contains the contact information to be rendered
class ContactCardModel extends Model {
  entities.Contact _contact;

  /// The Contact to display details for
  entities.Contact get contact => _contact;
  set contact(entities.Contact contact) {
    _contact = contact;
    notifyListeners();
  }
}
