// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_EXAMPLES_UI_PAINT_PAINT_VIEW_H_
#define TOPAZ_EXAMPLES_UI_PAINT_PAINT_VIEW_H_

#include <map>
#include <vector>

#include "examples/ui/lib/skia_view.h"
#include "lib/fxl/macros.h"
#include "third_party/skia/include/core/SkCanvas.h"
#include "third_party/skia/include/core/SkPath.h"

namespace examples {

class PaintView : public scenic::SkiaView {
 public:
  PaintView(scenic::ViewContext view_context);
  ~PaintView() override = default;

 private:
  // |scenic::V1BaseView|
  void OnSceneInvalidated(
      fuchsia::images::PresentationInfo presentation_info) override;
  bool OnInputEvent(fuchsia::ui::input::InputEvent event) override;

  void DrawContent(SkCanvas* canvas);
  SkPath CurrentPath(uint32_t pointer_id);

  std::map<uint32_t, std::vector<SkPoint>> points_;
  std::vector<SkPath> paths_;

  FXL_DISALLOW_COPY_AND_ASSIGN(PaintView);
};

}  // namespace examples

#endif  // TOPAZ_EXAMPLES_UI_PAINT_PAINT_VIEW_H_
