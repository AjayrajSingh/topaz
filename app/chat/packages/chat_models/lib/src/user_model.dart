// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
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

  /// Gets the effective display name, which is the display name when provided,
  /// and the email address when the display name is not provided.
  String get effectiveDisplayName => displayName ?? email;
}

/// A model for holding each participant's photo url.
class UserModel extends Model {
  final Map<String, Participant> _participants = <String, Participant>{};
  final List<Participant> _currentParticipants = <Participant>[];

  /// Gets all the current participants who are added in the most recent batch.
  List<Participant> get currentParticipants =>
      new UnmodifiableListView<Participant>(_currentParticipants);

  /// Gets the [Participant] associated with the given email.
  Participant getParticipant(String email) => _participants[email];

  /// Updates the model.
  void updateModel(Map<String, Participant> participants) {
    _participants.addAll(participants);
    _currentParticipants
      ..clear()
      ..addAll(participants.values);
    notifyListeners();
  }
}
