// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "examples/ui/lib/image_info.h"

#include "lib/fxl/logging.h"

namespace scenic_lib {
namespace skia {

SkImageInfo MakeSkImageInfo(const images::ImageInfo& image_info) {
  FXL_DCHECK(image_info.tiling == images::Tiling::LINEAR);

  switch (image_info.pixel_format) {
    case images::PixelFormat::BGRA_8:
      return SkImageInfo::Make(image_info.width, image_info.height,
                               kBGRA_8888_SkColorType, kOpaque_SkAlphaType);
    case images::PixelFormat::YUY2:
      FXL_CHECK(false) << "Not implemented.";
      return SkImageInfo();
  }

  FXL_NOTREACHED();
}

}  // namespace skia
}  // namespace scenic_lib
