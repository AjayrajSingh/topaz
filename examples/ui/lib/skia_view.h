// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef LIB_UI_VIEW_FRAMEWORK_SKIA_VIEW_H_
#define LIB_UI_VIEW_FRAMEWORK_SKIA_VIEW_H_

#include "examples/ui/lib/host_canvas_cycler.h"
#include "lib/fxl/macros.h"
#include "lib/ui/view_framework/base_view.h"

namespace mozart {

// Abstract base class for views which use Skia software rendering to a
// single full-size surface.
class SkiaView : public BaseView {
 public:
  SkiaView(ViewManagerPtr view_manager,
           f1dl::InterfaceRequest<ViewOwner> view_owner_request,
           const std::string& label);
  ~SkiaView() override;

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

 private:
  scenic_lib::skia::HostCanvasCycler canvas_cycler_;

  FXL_DISALLOW_COPY_AND_ASSIGN(SkiaView);
};

}  // namespace mozart

#endif  // LIB_UI_VIEW_FRAMEWORK_SKIA_VIEW_H_
