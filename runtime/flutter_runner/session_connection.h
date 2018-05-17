// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include <zx/eventpair.h>

#include "flutter/flow/compositor_context.h"
#include "flutter/flow/scene_update_context.h"
#include "lib/fidl/cpp/interface_handle.h"
#include "lib/fxl/functional/closure.h"
#include "lib/fxl/macros.h"
#include "lib/ui/scenic/client/resources.h"
#include "lib/ui/scenic/client/session.h"
#include "vulkan_surface_producer.h"

namespace flutter {

using OnMetricsUpdate = std::function<void(double /* device pixel ratio */)>;

// The component residing on the GPU thread that is responsible for
// maintaining the Scenic session connection and presenting node updates.
class SessionConnection final {
 public:
  SessionConnection(fidl::InterfaceHandle<ui::Scenic> scenic,
                    std::string debug_label,
                    zx::eventpair import_token,
                    OnMetricsUpdate session_metrics_did_change_callback,
                    fxl::Closure session_error_callback,
                    zx_handle_t vsync_event_handle);

  ~SessionConnection();

  bool has_metrics() const { return scene_update_context_.has_metrics(); }

  const gfx::MetricsPtr& metrics() const {
    return scene_update_context_.metrics();
  }

  flow::SceneUpdateContext& scene_update_context() {
    return scene_update_context_;
  }

  scenic_lib::ImportNode& root_node() { return root_node_; }

  void Present(flow::CompositorContext::ScopedFrame& frame);

 private:
  const std::string debug_label_;
  ui::ScenicPtr scenic_;
  scenic_lib::Session session_;
  scenic_lib::ImportNode root_node_;
  std::unique_ptr<VulkanSurfaceProducer> surface_producer_;
  flow::SceneUpdateContext scene_update_context_;
  OnMetricsUpdate metrics_changed_callback_;
  zx_handle_t vsync_event_handle_;

  void OnSessionEvents(fidl::VectorPtr<ui::Event> events);

  void EnqueueClearOps();

  void PresentSession();

  static void ToggleSignal(zx_handle_t handle, bool raise);

  FXL_DISALLOW_COPY_AND_ASSIGN(SessionConnection);
};

}  // namespace flutter
