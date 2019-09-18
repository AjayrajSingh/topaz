// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_EXAMPLES_UI_LIB_SKIA_VIEW_H_
#define TOPAZ_EXAMPLES_UI_LIB_SKIA_VIEW_H_

#include <lib/ui/base_view/cpp/base_view.h>

#include "examples/ui/lib/host_canvas_cycler.h"
#include "src/lib/fxl/logging.h"
#include "src/lib/fxl/macros.h"

namespace scenic {

// Abstract base class for views which use Skia software rendering to a
// single full-size surface.
class SkiaView : public scenic::BaseView {
 public:
  SkiaView(scenic::ViewContext view_context, const std::string& label);
  ~SkiaView() override = default;

  // Acquires a canvas for rendering.
  // At most one canvas can be acquired at a time.
  // The client is responsible for clearing the canvas.
  // Returns nullptr if the view does not have a size.
  //
  // The returned canvas uses the view's logical coordinate system but is
  // backed by a surface with the same |physical_size()| as the view.
  // In other words any content which the view draws into the canvas will
  // automatically be scaled according to the view's |metrics()|.
  SkCanvas* AcquireCanvas();

  // Releases the canvas most recently acquired using |AcquireCanvas()|.
  // Sets the view's content texture to be backed by the canvas.
  void ReleaseAndSwapCanvas();

 protected:
  // |scenic::SessionListener|
  void OnScenicError(std::string error) override {
    FXL_LOG(ERROR) << "Scenic Error " << error;
  }

 private:
  scenic::skia::HostCanvasCycler canvas_cycler_;

  FXL_DISALLOW_COPY_AND_ASSIGN(SkiaView);
};

}  // namespace scenic

#endif  // TOPAZ_EXAMPLES_UI_LIB_SKIA_VIEW_H_
