// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/examples/ui/jank/jank_view.h"

#include <unistd.h>

#include <string>

#include "src/lib/fxl/logging.h"
#include "src/lib/fxl/macros.h"
#include "src/lib/fxl/time/time_delta.h"

namespace examples {

namespace {
constexpr SkScalar kButtonWidth = 300;
constexpr SkScalar kButtonHeight = 24;
constexpr SkScalar kTextSize = 10;
constexpr SkScalar kMargin = 10;
}  // namespace

const JankView::Button JankView::kButtons[] = {
    {"Hang for 10 seconds", Action::kHang10},
    {"Stutter for 30 seconds", Action::kStutter30},
    {"Crash!", Action::kCrash},
};

JankView::JankView(scenic::ViewContext view_context,
                   fuchsia::fonts::ProviderPtr font_provider)
    : SkiaView(std::move(view_context), "Jank"),
      font_loader_(std::move(font_provider)) {
  font_loader_.LoadDefaultFont([this](sk_sp<SkTypeface> typeface) {
    FXL_CHECK(typeface);  // TODO(jeffbrown): Fail gracefully.
    typeface_ = std::move(typeface);
    InvalidateScene();
  });
}

void JankView::OnSceneInvalidated(
    fuchsia::images::PresentationInfo presentation_info) {
  if (!typeface_)
    return;

  SkCanvas* canvas = AcquireCanvas();
  if (!canvas)
    return;
  DrawContent(canvas);
  ReleaseAndSwapCanvas();

  // Stutter if needed.
  if (stutter_end_time_ > fxl::TimePoint::Now())
    sleep(2);

  // Animate.
  InvalidateScene();
}

void JankView::DrawContent(SkCanvas* canvas) {
  SkScalar hsv[3] = {
      static_cast<SkScalar>(
          fmod(fxl::TimePoint::Now().ToEpochDelta().ToSecondsF() * 60, 360.)),
      1, 1};
  canvas->clear(SkHSVToColor(hsv));

  SkScalar x = kMargin;
  SkScalar y = kMargin;
  for (const auto& button : kButtons) {
    DrawButton(canvas, button.label,
               SkRect::MakeXYWH(x, y, kButtonWidth, kButtonHeight));
    y += kButtonHeight + kMargin;
  }
}

void JankView::DrawButton(SkCanvas* canvas, const char* label,
                          const SkRect& bounds) {
  SkPaint boxPaint;
  boxPaint.setColor(SkColorSetRGB(200, 200, 200));
  canvas->drawRect(bounds, boxPaint);
  boxPaint.setColor(SkColorSetRGB(40, 40, 40));
  boxPaint.setStyle(SkPaint::kStroke_Style);
  canvas->drawRect(bounds, boxPaint);

  SkRect textBounds;
  SkFont textFont;
  textFont.setTypeface(typeface_);
  textFont.setSize(kTextSize);
  textFont.measureText(label, strlen(label), SkTextEncoding::kUTF8,
                       &textBounds);

  SkPaint textPaint;
  textPaint.setColor(SK_ColorBLACK);
  textPaint.setAntiAlias(true);
  canvas->drawSimpleText(label, strlen(label), SkTextEncoding::kUTF8,
                         bounds.centerX() - textBounds.centerX(),
                         bounds.centerY() - textBounds.centerY(), textFont,
                         textPaint);
}

void JankView::OnInputEvent(fuchsia::ui::input::InputEvent event) {
  if (event.is_pointer()) {
    const fuchsia::ui::input::PointerEvent& pointer = event.pointer();
    if (pointer.phase == fuchsia::ui::input::PointerEventPhase::DOWN) {
      SkScalar x = pointer.x;
      SkScalar y = pointer.y;
      if (x >= kMargin && x <= kButtonWidth + kMargin) {
        int index = (y - kMargin) / (kButtonHeight + kMargin);
        if (index >= 0 &&
            size_t(index) < sizeof(kButtons) / sizeof(kButtons[0]) &&
            y < (kButtonHeight + kMargin) * (index + 1))
          OnClick(kButtons[index]);
        return;
      }
    }
  }
}

void JankView::OnClick(const Button& button) {
  switch (button.action) {
    case Action::kHang10: {
      sleep(10);
      break;
    }

    case Action::kStutter30: {
      stutter_end_time_ =
          fxl::TimePoint::Now() + fxl::TimeDelta::FromSeconds(30);
      break;
    }

    case Action::kCrash: {
      abort();
      break;
    }
  }
}

}  // namespace examples
