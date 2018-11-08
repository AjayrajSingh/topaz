// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_EXAMPLES_MEDIAPLAYER_MEDIAPLAYER_SKIA_MEDIAPLAYER_PARAMS_H_
#define TOPAZ_EXAMPLES_MEDIAPLAYER_MEDIAPLAYER_SKIA_MEDIAPLAYER_PARAMS_H_

#include <string>

#include "lib/fxl/command_line.h"

namespace examples {

class MediaPlayerParams {
 public:
  MediaPlayerParams(const fxl::CommandLine& command_line);
  ~MediaPlayerParams() = default;

  bool is_valid() const { return is_valid_; }

  const std::string& url() const { return url_; }

 private:
  void Usage();

  bool is_valid_;

  std::string path_;
  std::string url_;
};

}  // namespace examples

#endif  // TOPAZ_EXAMPLES_MEDIAPLAYER_MEDIAPLAYER_SKIA_MEDIAPLAYER_PARAMS_H_
