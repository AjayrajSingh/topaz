// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "examples/ui/lib/image_info.h"

#include "lib/fxl/logging.h"

namespace scenic {
namespace skia {

SkImageInfo MakeSkImageInfo(const fuchsia::images::ImageInfo& image_info) {
  FXL_DCHECK(image_info.tiling == fuchsia::images::Tiling::LINEAR);

  switch (image_info.pixel_format) {
    case fuchsia::images::PixelFormat::BGRA_8:
      return SkImageInfo::Make(image_info.width, image_info.height,
                               kBGRA_8888_SkColorType, kOpaque_SkAlphaType);
    case fuchsia::images::PixelFormat::YUY2:
    // The default case here is intended to be temporary - this will go back to
    // not having a default once garnet's NV12 value can be explicitly
    // referenced here.
    default:
      FXL_CHECK(false) << "Not implemented: "
                       << static_cast<int>(image_info.pixel_format);
      return SkImageInfo();
  }

  FXL_NOTREACHED();
}

}  // namespace skia
}  // namespace scenic
