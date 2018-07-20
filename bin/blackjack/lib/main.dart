// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app.dart/logging.dart';

import 'src/deck.dart';
import 'src/playing_card.dart';

void main() {
  setupLogger(name: 'tictactoe gameboard');

  PlayingCard aceHearts = PlayingCard.fromAscii('AH');
  log.info('Ace of Hearts: ${aceHearts.toString()}');

  Deck deck = new Deck();
  log.info('Card dealt: ${deck.dealCard().toString()}');
}
