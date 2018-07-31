// Copyright 2015 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_BIN_UI_BENCHMARKS_IMAGE_GRID_BENCHMARK_CPP_IMAGE_GRID_BENCHMARK_H_
#define TOPAZ_BIN_UI_BENCHMARKS_IMAGE_GRID_BENCHMARK_CPP_IMAGE_GRID_BENCHMARK_H_

#include "examples/ui/lib/skia_view.h"
#include "garnet/lib/ui/scenic/util/rk4_spring_simulation.h"
#include "lib/fxl/macros.h"

class SkCanvas;

namespace image_grid_benchmark {

class Frame;
class Rasterizer;

class ImageGridBenchmark : public mozart::BaseView {
 public:
  ImageGridBenchmark(
      fuchsia::ui::viewsv1::ViewManagerPtr view_manager,
      fidl::InterfaceRequest<fuchsia::ui::viewsv1token::ViewOwner>
          view_owner_request);

  ~ImageGridBenchmark() override;

 private:
  // |BaseView|:
  void OnSceneInvalidated(
      fuchsia::images::PresentationInfo presentation_info) override;

  void CreateScene();
  void UpdateScene(uint64_t presentation_time);

  bool scene_created_ = false;
  scenic::ShapeNode background_node_;
  scenic::EntityNode cards_parent_node_;
  std::vector<scenic::ShapeNode> cards_;

  uint64_t start_time_ = 0u;
  uint64_t last_update_time_ = 0u;
  float x_offset_ = 0.f;
  scenic::RK4SpringSimulation spring_;

  FXL_DISALLOW_COPY_AND_ASSIGN(ImageGridBenchmark);
};

}  // namespace image_grid_benchmark

#endif  // TOPAZ_BIN_UI_BENCHMARKS_IMAGE_GRID_BENCHMARK_CPP_IMAGE_GRID_BENCHMARK_H_
