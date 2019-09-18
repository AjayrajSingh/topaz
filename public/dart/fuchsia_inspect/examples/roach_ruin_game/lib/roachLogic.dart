// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

class RoachLogic {
  int counter = 0;
  String roachLive = 'lib/images/live.png';
  String roachDead = 'lib/images/dead.png';
  String currRoach = 'lib/images/live.png';
  String hamU = 'lib/images/hammerup.png';
  String hamD = 'lib/images/hammerdown.png';
  String currHam = 'lib/images/hammerup.png';
  String person = 'lib/images/person.png';
  bool hammerUp = true;

  bool changeHammer({bool hamIsUp = true}) {
    return !hamIsUp;
  }

  int increaseCounter(int currCount) {
    int newCount = currCount + 1;
    return newCount;
  }

  String hammerUpright() {
    return hamU;
  }

  String hammerDown() {
    return hamD;
  }

  String roachLiving() {
    return roachLive;
  }

  String roachNotLiving() {
    return roachDead;
  }
}
