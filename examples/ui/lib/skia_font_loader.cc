// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "examples/ui/lib/skia_font_loader.h"

#include <utility>

#include "examples/ui/lib/skia_vmo_data.h"
#include "third_party/skia/include/core/SkFontMgr.h"

namespace scenic {

SkiaFontLoader::SkiaFontLoader(fuchsia::fonts::ProviderPtr font_provider)
    : font_provider_(std::move(font_provider)) {}

SkiaFontLoader::~SkiaFontLoader() {}

void SkiaFontLoader::LoadFont(fuchsia::fonts::Request request,
                              FontCallback callback) {
  // TODO(jeffbrown): Handle errors in case the font provider itself dies.
  font_provider_->GetFont(
      std::move(request), [this, callback = std::move(callback)](
                              fuchsia::fonts::ResponsePtr response) {
        if (response) {
          fsl::SizedVmo vmo;
          if (!fsl::SizedVmo::FromTransport(std::move(response->buffer),
                                            &vmo)) {
            callback(nullptr);
            return;
          }
          sk_sp<SkData> font_data = MakeSkDataFromVMO(vmo);
          if (font_data) {
            callback(
                SkFontMgr::RefDefault()->makeFromData(std::move(font_data)));
            return;
          }
        }
        callback(nullptr);
      });
}

void SkiaFontLoader::LoadDefaultFont(FontCallback callback) {
  fuchsia::fonts::Request request;
  request.family = "Roboto";
  LoadFont(std::move(request), std::move(callback));
}

}  // namespace scenic
