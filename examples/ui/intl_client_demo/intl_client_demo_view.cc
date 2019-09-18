// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "intl_client_demo_view.h"

#include "src/lib/fidl_fuchsia_intl_ext/cpp/fidl_ext.h"
#include "src/lib/fxl/logging.h"
#include "third_party/skia/include/core/SkFont.h"
#include "third_party/skia/include/core/SkPaint.h"

namespace examples {

namespace {
constexpr SkScalar kTextSize = 30;

// Return the first locale ID in the given profile, or "[none]" if the
// profile is invalid.
const std::string GetFirstLocale(const fuchsia::intl::Profile& profile) {
  if (profile.has_locales()) {
    return profile.locales()[0].id;
  }
  return "[none]";
}

}  // namespace

IntlClientDemoView::IntlClientDemoView(scenic::ViewContext view_context)
    : SkiaView(std::move(view_context), "ViewConfig Demo"),
      font_loader_(
          component_context()->svc()->Connect<fuchsia::fonts::Provider>()),
      intl_property_provider_client_(
          component_context()
              ->svc()
              ->Connect<fuchsia::intl::PropertyProvider>()) {
  // Asynchronously load the font we need in order to render text.
  fuchsia::fonts::TypefaceRequest font_request{};
  font_request.set_query(std::move(fuchsia::fonts::TypefaceQuery{}.set_family(
      fuchsia::fonts::FamilyName{.name = "Roboto"})));
  font_loader_.LoadFont(std::move(font_request),
                        [this](sk_sp<SkTypeface> typeface) {
                          if (!typeface) {
                            FXL_LOG(ERROR) << "Failed to load font";
                            return;
                          }
                          FXL_LOG(INFO) << "Loaded font";
                          typeface_ = std::move(typeface);
                          InvalidateScene();
                        });
  intl_property_provider_client_.events().OnChange = [this]() {
    FetchIntlProfile();
  };
  // Load the initial profile.
  FetchIntlProfile();
}

void IntlClientDemoView::FetchIntlProfile() {
  intl_property_provider_client_->GetProfile(
      [this](fuchsia::intl::Profile new_profile) {
        SetIntlProfile(std::move(new_profile));
      });
}

void IntlClientDemoView::SetIntlProfile(fuchsia::intl::Profile new_profile) {
  FXL_LOG(INFO) << "Got a new intl Profile";
  if (intl_profile_ != new_profile) {
    intl_profile_ = std::move(new_profile);
    InvalidateScene();
  }
}

void IntlClientDemoView::OnPropertiesChanged(
    fuchsia::ui::gfx::ViewProperties old_properties) {
  InvalidateScene();
}

void IntlClientDemoView::OnSceneInvalidated(
    fuchsia::images::PresentationInfo presentation_info) {
  if (!typeface_) {
    FXL_LOG(ERROR) << "No typeface loaded";
    return;
  }

  SkCanvas* canvas = AcquireCanvas();
  if (!canvas) {
    FXL_LOG(ERROR) << "Couldn't acquire canvas";
    return;
  }

  Draw(canvas);
  ReleaseAndSwapCanvas();
  // If we want to animate, add a call to InvalidateScene() here.
}

void IntlClientDemoView::Draw(SkCanvas* canvas) {
  canvas->clear(SkColorSetRGB(180, 200, 200));

  SkPaint text_paint;
  text_paint.setColor(SK_ColorBLACK);
  text_paint.setAntiAlias(true);
  text_paint.setStyle(SkPaint::kFill_Style);

  SkFont font;
  font.setSize(kTextSize);
  font.setTypeface(typeface_);

  std::vector<std::string> lines = {"Locale:", GetFirstLocale(intl_profile_)};

  // Start 1/3 of the way from the top.
  float v_offset = logical_size().y / 3.0;
  SkRect text_bounds{};

  for (const auto& line : lines) {
    font.measureText(line.c_str(), line.size(), SkTextEncoding::kUTF8,
                     &text_bounds);

    // Draw the text horizontally centered on the screen.
    canvas->drawSimpleText(line.c_str(), line.size(), SkTextEncoding::kUTF8,
                           (logical_size().x - text_bounds.width()) / 2,
                           v_offset, font, text_paint);

    v_offset += (text_bounds.height() * 1.5);
  }
}

}  // namespace examples
