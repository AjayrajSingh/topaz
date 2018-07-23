// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.widgets/model.dart';

import 'deck.dart';
import 'hand_model.dart';

class BlackjackModel extends Model {
  List<PlayerModel> players;
  HandModel dealerHand;
  Deck deck;

  BlackjackModel()
      : players = <PlayerModel>[],
        dealerHand = new HandModel(),
        deck = new Deck();
}
