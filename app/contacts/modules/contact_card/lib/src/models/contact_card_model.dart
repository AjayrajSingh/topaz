// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.schemas.dart/com.fuchsia.contact.dart' as entities;
import 'package:lib.widgets/model.dart';

/// The [ContactCardModel] contains the contact information to be rendered
class ContactCardModel extends Model {
  bool _error = false;
  entities.ContactEntityData _contact;

  /// The Contact to display details for
  entities.ContactEntityData get contact => _contact;
  set contact(entities.ContactEntityData contact) {
    _contact = contact;
    notifyListeners();
  }

  /// If there is an error with the module
  bool get error => _error;
  set error(bool error) {
    _error = error;
    notifyListeners();
  }
}
