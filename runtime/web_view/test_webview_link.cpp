// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This just tests that a binary linked against the WebKit library can be run.
// It doesn't exercise the library since that depends on being able to talk to
// the compositor which may not work on test bots.

#include "WebView.h"

int main(int argc, const char** argv) {
    WebView webView;
    return 0;
}
