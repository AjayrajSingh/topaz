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

void SkiaFontLoader::LoadFont(fuchsia::fonts::TypefaceRequest request,
                              FontCallback callback) {
  // TODO(jeffbrown): Handle errors in case the font provider itself dies.
  font_provider_->GetTypeface(
      std::move(request), [callback = std::move(callback)](
                              fuchsia::fonts::TypefaceResponse response) {
        if (!response.IsEmpty()) {
          fuchsia::mem::Buffer buffer{};
          response.buffer().Clone(&buffer);
          fsl::SizedVmo vmo;
          if (!fsl::SizedVmo::FromTransport(std::move(buffer), &vmo)) {
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
  fuchsia::fonts::TypefaceRequest request{};
  request.set_query(std::move(fuchsia::fonts::TypefaceQuery{}.set_family(
      fuchsia::fonts::FamilyName{.name = "Roboto"})));
  LoadFont(std::move(request), std::move(callback));
}

}  // namespace scenic
