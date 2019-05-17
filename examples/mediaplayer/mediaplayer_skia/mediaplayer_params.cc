// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/examples/mediaplayer/mediaplayer_skia/mediaplayer_params.h"

#include <iostream>

#include "src/lib/fxl/strings/split_string.h"

namespace examples {

MediaPlayerParams::MediaPlayerParams(const fxl::CommandLine& command_line) {
  is_valid_ = false;

  bool url_found = false;

  for (const std::string& arg : command_line.positional_args()) {
    if (url_found) {
      Usage();
      std::cerr << "At most one url-or-path allowed\n";
      return;
    }

    if (arg.compare(0, 1, "/") == 0) {
      url_ = "file://";
      url_.append(arg);
      url_found = true;
    } else if (arg.compare(0, 7, "http://") == 0 ||
               arg.compare(0, 8, "https://") == 0 ||
               arg.compare(0, 8, "file:///") == 0) {
      url_ = arg;
      url_found = true;
    } else {
      Usage();
      std::cerr << "Url-or-path must start with '/' 'http://', 'https://' or "
                   "'file:///'\n";
      return;
    }
  }

  if (!url_found) {
    Usage();
    return;
  }

  is_valid_ = true;
}

void MediaPlayerParams::Usage() {
  std::cerr << "mediaplayer_skia usage:\n";
  std::cerr << "    present_view mediaplayer_skia url-or-path\n";
}

}  // namespace examples
