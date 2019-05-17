// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/examples/ui/paint/paint_view.h"

#include <hid/usages.h>

#include "lib/component/cpp/connect.h"
#include "src/lib/fxl/logging.h"
#include "src/lib/fxl/macros.h"
#include "third_party/skia/include/core/SkColor.h"
#include "third_party/skia/include/core/SkRect.h"

namespace examples {

PaintView::PaintView(scenic::ViewContext view_context)
    : SkiaView(std::move(view_context), "Paint") {}

void PaintView::OnSceneInvalidated(
    fuchsia::images::PresentationInfo presentation_info) {
  SkCanvas* canvas = AcquireCanvas();
  if (!canvas)
    return;

  DrawContent(canvas);
  ReleaseAndSwapCanvas();
}

void PaintView::DrawContent(SkCanvas* canvas) {
  canvas->clear(SK_ColorWHITE);

  SkPaint paint;
  paint.setColor(0xFFFF00FF);
  paint.setAntiAlias(true);
  paint.setStyle(SkPaint::kStroke_Style);
  paint.setStrokeWidth(SkIntToScalar(3));

  for (auto path : paths_) {
    canvas->drawPath(path, paint);
  }

  paint.setColor(SK_ColorBLUE);
  for (auto iter = points_.begin(); iter != points_.end(); ++iter) {
    if (!iter->second.empty()) {
      canvas->drawPath(CurrentPath(iter->first), paint);
    }
  }
}

SkPath PaintView::CurrentPath(uint32_t pointer_id) {
  SkPath path;
  if (points_.count(pointer_id)) {
    uint32_t count = 0;
    for (auto point : points_.at(pointer_id)) {
      if (count++ == 0) {
        path.moveTo(point);
      } else {
        path.lineTo(point);
      }
    }
  }
  return path;
}

void PaintView::OnInputEvent(fuchsia::ui::input::InputEvent event) {
  if (event.is_pointer()) {
    const fuchsia::ui::input::PointerEvent& pointer = event.pointer();
    uint32_t pointer_id = pointer.device_id * 32 + pointer.pointer_id;
    switch (pointer.phase) {
      case fuchsia::ui::input::PointerEventPhase::DOWN:
      case fuchsia::ui::input::PointerEventPhase::MOVE:
        // On down + move, keep appending points to the path being built
        // For mouse only draw if left button is pressed
        if (pointer.type == fuchsia::ui::input::PointerEventType::TOUCH ||
            pointer.type == fuchsia::ui::input::PointerEventType::STYLUS ||
            (pointer.type == fuchsia::ui::input::PointerEventType::MOUSE &&
             pointer.buttons & fuchsia::ui::input::kMousePrimaryButton)) {
          if (!points_.count(pointer_id)) {
            points_[pointer_id] = std::vector<SkPoint>();
          }
          points_.at(pointer_id).push_back(SkPoint::Make(pointer.x, pointer.y));
        }
        break;
      case fuchsia::ui::input::PointerEventPhase::UP:
        // Path is done, add it to the list of paths and reset the list of
        // points
        paths_.push_back(CurrentPath(pointer_id));
        points_.erase(pointer_id);
        break;
      default:
        break;
    }
  } else if (event.is_keyboard()) {
    const fuchsia::ui::input::KeyboardEvent& keyboard = event.keyboard();
    if (keyboard.hid_usage == HID_USAGE_KEY_ESC) {
      // clear
      paths_.clear();
    }
  }

  InvalidateScene();
}

}  // namespace examples
