// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.widgets/model.dart';

import 'hand_model.dart';

class PlayerModel extends Model {
  HandModel _handModel;
  HandModel _splitHandModel;
  int _cashAtTable;

  /// Constructor
  PlayerModel()
      : _cashAtTable = 0,
        _handModel = new HandModel();

  /// Is it OK for this player to split
  bool get canSplit => _splitHandModel == null && _handModel.canSplit;

  /// Did this player split their hand
  bool get hasSplit => _splitHandModel != null;

  /// The cards for this player's main hand
  HandModel get hand => _handModel;

  /// The cards for this player's second hand if split
  HandModel get splitHand => _splitHandModel;

  int get cashAtTable => _cashAtTable;

  void addCash(int cash) {
    _cashAtTable += cash;
    notifyListeners();
  }

  int cashOut() {
    int result = _cashAtTable;
    _cashAtTable = 0;
    notifyListeners();
    return result;
  }

  /// Commit money for the current hand (remove it from player's table money)
  void commitBet() {
    _cashAtTable -= hand.bet;
    notifyListeners();
  }

  /// Clear the game and default the next bet to the same as the last
  void nextHand() {
    _handModel.clear();
    _splitHandModel = null;
    if (_handModel.bet > _cashAtTable) {
      // Make sure this bet is an even multiple of the min bet
      _handModel.bet = _cashAtTable < 0
          ? 0
          : _cashAtTable - (_cashAtTable % HandModel.minChipValue);
    }
    notifyListeners();
  }

  void split() {
    assert(_handModel.canSplit);
    // TODO: Notify user if they don't have enough at the table
    _cashAtTable -= _handModel.bet;
    _splitHandModel = _handModel.split()..bet = _handModel.bet;
    notifyListeners();
  }
}
