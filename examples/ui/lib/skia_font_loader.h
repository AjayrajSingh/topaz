// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_EXAMPLES_UI_LIB_SKIA_FONT_LOADER_H_
#define TOPAZ_EXAMPLES_UI_LIB_SKIA_FONT_LOADER_H_

#include <fuchsia/fonts/cpp/fidl.h>
#include <lib/fit/function.h>

#include <functional>

#include "src/lib/fxl/macros.h"
#include "third_party/skia/include/core/SkTypeface.h"

namespace scenic {

// Loads fonts from a font provider.
class SkiaFontLoader {
 public:
  using FontCallback = fit::function<void(sk_sp<SkTypeface>)>;

  SkiaFontLoader(fuchsia::fonts::ProviderPtr font_provider);
  ~SkiaFontLoader();

  // Loads the requested font and invokes the callback when done.
  // If the request fails, the callback will receive a null typeface.
  void LoadFont(fuchsia::fonts::TypefaceRequest request, FontCallback callback);

  // Loads the default font and invokes the callback when done.
  // If the request fails, the callback will receive a null typeface.
  void LoadDefaultFont(FontCallback callback);

 private:
  fuchsia::fonts::ProviderPtr font_provider_;

  FXL_DISALLOW_COPY_AND_ASSIGN(SkiaFontLoader);
};

}  // namespace scenic

#endif  // TOPAZ_EXAMPLES_UI_LIB_SKIA_FONT_LOADER_H_
