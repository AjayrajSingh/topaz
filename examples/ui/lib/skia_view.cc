// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "examples/ui/lib/skia_view.h"

namespace scenic {

SkiaView::SkiaView(scenic::ViewContext view_context, const std::string& label)
    : V1BaseView(std::move(view_context), label), canvas_cycler_(session()) {
  parent_node().AddChild(canvas_cycler_);
}

SkiaView::~SkiaView() = default;

SkCanvas* SkiaView::AcquireCanvas() {
  if (!has_logical_size() || !has_metrics())
    return nullptr;

  SkCanvas* canvas =
      canvas_cycler_.AcquireCanvas(logical_size().width, logical_size().height,
                                   metrics().scale_x, metrics().scale_y);
  if (!canvas)
    return canvas;

  canvas_cycler_.SetTranslation(logical_size().width * .5f,
                                logical_size().height * .5f, 0.f);
  return canvas;
}

void SkiaView::ReleaseAndSwapCanvas() { canvas_cycler_.ReleaseAndSwapCanvas(); }

}  // namespace scenic
