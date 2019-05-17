// Copyright 2015 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_EXAMPLES_UI_NOODLES_NOODLES_VIEW_H_
#define TOPAZ_EXAMPLES_UI_NOODLES_NOODLES_VIEW_H_

#include <fuchsia/images/cpp/fidl.h>
#include "examples/ui/lib/skia_view.h"
#include "src/lib/fxl/macros.h"

class SkCanvas;

namespace examples {

class Frame;
class Rasterizer;

class NoodlesView : public scenic::SkiaView {
 public:
  NoodlesView(scenic::ViewContext view_context);
  ~NoodlesView() override = default;

 private:
  // |scenic::BaseView|
  void OnSceneInvalidated(
      fuchsia::images::PresentationInfo presentation_info) override;

  void Draw(SkCanvas* canvas, float t);

  uint64_t start_time_ = 0u;
  int wx_ = 0;
  int wy_ = 0;

  FXL_DISALLOW_COPY_AND_ASSIGN(NoodlesView);
};

}  // namespace examples

#endif  // TOPAZ_EXAMPLES_UI_NOODLES_NOODLES_VIEW_H_
