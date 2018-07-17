// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

class Score {
  final int xScore;
  final int oScore;

  Score(this.xScore, this.oScore)
      : assert(xScore != null),
        assert(oScore != null);
}
