// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_EXAMPLES_UI_PAINT_PAINT_VIEW_H_
#define TOPAZ_EXAMPLES_UI_PAINT_PAINT_VIEW_H_

#include <fuchsia/images/cpp/fidl.h>
#include <fuchsia/ui/input/cpp/fidl.h>
#include <map>
#include <vector>
#include "src/lib/fxl/macros.h"
#include "third_party/skia/include/core/SkCanvas.h"
#include "third_party/skia/include/core/SkPath.h"

#include "examples/ui/lib/skia_view.h"

namespace examples {

class PaintView : public scenic::SkiaView {
 public:
  PaintView(scenic::ViewContext view_context);
  ~PaintView() override = default;

 private:
  // |scenic::BaseView|
  void OnSceneInvalidated(
      fuchsia::images::PresentationInfo presentation_info) override;
  void OnInputEvent(fuchsia::ui::input::InputEvent event) override;

  void DrawContent(SkCanvas* canvas);
  SkPath CurrentPath(uint32_t pointer_id);

  std::map<uint32_t, std::vector<SkPoint>> points_;
  std::vector<SkPath> paths_;

  FXL_DISALLOW_COPY_AND_ASSIGN(PaintView);
};

}  // namespace examples

#endif  // TOPAZ_EXAMPLES_UI_PAINT_PAINT_VIEW_H_
