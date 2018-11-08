// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_EXAMPLES_UI_JANK_JANK_VIEW_H_
#define TOPAZ_EXAMPLES_UI_JANK_JANK_VIEW_H_

#include "examples/ui/lib/skia_font_loader.h"
#include "examples/ui/lib/skia_view.h"
#include "lib/fxl/macros.h"
#include "lib/fxl/time/time_point.h"
#include "third_party/skia/include/core/SkCanvas.h"
#include "third_party/skia/include/core/SkColor.h"
#include "third_party/skia/include/core/SkRect.h"
#include "third_party/skia/include/core/SkTypeface.h"

namespace examples {

class JankView : public scenic::SkiaView {
 public:
  JankView(scenic::ViewContext view_context,
           fuchsia::fonts::ProviderPtr font_provider);
  ~JankView() override = default;

 private:
  enum class Action {
    kHang10,
    kStutter30,
    kCrash,
  };

  struct Button {
    const char* label;
    Action action;
  };

  static const Button kButtons[];

  // |scenic::V1BaseView|
  void OnSceneInvalidated(
      fuchsia::images::PresentationInfo presentation_info) override;
  bool OnInputEvent(fuchsia::ui::input::InputEvent event) override;

  void DrawContent(SkCanvas* canvas);
  void DrawButton(SkCanvas* canvas, const char* label, const SkRect& bounds);
  void OnClick(const Button& button);

  mozart::SkiaFontLoader font_loader_;
  sk_sp<SkTypeface> typeface_;

  fxl::TimePoint stutter_end_time_;

  FXL_DISALLOW_COPY_AND_ASSIGN(JankView);
};

}  // namespace examples

#endif  // TOPAZ_EXAMPLES_UI_JANK_JANK_VIEW_H_
