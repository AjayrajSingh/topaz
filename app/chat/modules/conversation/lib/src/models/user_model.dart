// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.widgets/model.dart';
import 'package:meta/meta.dart';

/// The Participant model class.
class Participant {
  /// The email of the participant, which must not be null.
  final String email;

  /// An optional display name of the participant.
  final String displayName;

  /// An optional photo url points to the profile picture of the participant.
  final String photoUrl;

  /// Creates a new instance of [Participant].
  Participant({@required this.email, this.displayName, this.photoUrl})
      : assert(email != null);
}

/// A model for holding each participant's photo url.
class UserModel extends Model {
  final Map<String, Participant> _participants = <String, Participant>{};

  /// Gets the [Participant] associated with the given email.
  Participant getParticipant(String email) => _participants[email];

  /// Updates the model.
  void updateModel(Map<String, Participant> participants) {
    _participants.addAll(participants);
    notifyListeners();
  }
}
