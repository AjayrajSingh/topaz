// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef GARNET_EXAMPLES_UI_PAINT_PAINT_VIEW_H_
#define GARNET_EXAMPLES_UI_PAINT_PAINT_VIEW_H_

#include <map>
#include <vector>

#include "examples/ui/lib/skia_view.h"
#include "lib/fxl/macros.h"
#include "third_party/skia/include/core/SkCanvas.h"
#include "third_party/skia/include/core/SkPath.h"

namespace examples {

class PaintView : public mozart::SkiaView {
 public:
  PaintView(views_v1::ViewManagerPtr view_manager,
            fidl::InterfaceRequest<views_v1_token::ViewOwner> view_owner_request);
  ~PaintView() override;

 private:
  // |BaseView|:
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

#endif  // GARNET_EXAMPLES_UI_PAINT_PAINT_VIEW_H_
