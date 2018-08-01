// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_FLUTTER_RUNNER_SESSION_CONNECTION_H_
#define TOPAZ_RUNTIME_FLUTTER_RUNNER_SESSION_CONNECTION_H_

#include <lib/fit/function.h>
#include <zx/eventpair.h>

#include "flutter/flow/compositor_context.h"
#include "flutter/flow/scene_update_context.h"
#include "lib/fidl/cpp/interface_handle.h"
#ifdef SCENIC_VIEWS2
#include "lib/fidl/cpp/optional.h"
#include "lib/fxl/functional/closure.h"
#endif
#include "flutter/fml/macros.h"
#include "lib/ui/scenic/cpp/resources.h"
#include "lib/ui/scenic/cpp/session.h"
#include "vulkan_surface_producer.h"

namespace flutter {

#ifndef SCENIC_VIEWS2
using OnMetricsUpdate = fit::function<void(double /* device pixel ratio */)>;
#else
using OnMetricsUpdate = fit::function<void(const fuchsia::ui::gfx::Metrics&)>;
#endif

// The component residing on the GPU thread that is responsible for
// maintaining the Scenic session connection and presenting node updates.
class SessionConnection final {
 public:
  SessionConnection(fidl::InterfaceHandle<fuchsia::ui::scenic::Scenic> scenic,
#ifndef SCENIC_VIEWS2
                    std::string debug_label, zx::eventpair import_token,
                    OnMetricsUpdate session_metrics_did_change_callback,
#else
                    fidl::InterfaceHandle<fuchsia::ui::scenic::Session> session,
                    zx::eventpair view_token, std::string debug_label,
#endif
                    fit::closure session_error_callback,
                    zx_handle_t vsync_event_handle);

  ~SessionConnection();

  bool has_metrics() const { return scene_update_context_.has_metrics(); }

  const fuchsia::ui::gfx::MetricsPtr& metrics() const {
    return scene_update_context_.metrics();
  }

#ifdef SCENIC_VIEWS2
  void set_metrics(const fuchsia::ui::gfx::Metrics& metrics) {
    fuchsia::ui::gfx::Metrics metrics_copy;
    metrics.Clone(&metrics_copy);
    scene_update_context_.set_metrics(
        fidl::MakeOptional(std::move(metrics_copy)));
  }

#endif
  flow::SceneUpdateContext& scene_update_context() {
    return scene_update_context_;
  }

#ifndef SCENIC_VIEWS2
  scenic::ImportNode& root_node() { return root_node_; }
#else
  scenic::ContainerNode& root_node() { return root_node_; }

  scenic::View* root_view() { return &root_view_; }
#endif

  void Present(flow::CompositorContext::ScopedFrame& frame);

 private:
  const std::string debug_label_;
  fuchsia::ui::scenic::ScenicPtr scenic_;
  scenic::Session session_wrapper_;
#ifndef SCENIC_VIEWS2
  scenic::ImportNode root_node_;
#else
  scenic::View root_view_;
  scenic::EntityNode root_node_;
#endif
  std::unique_ptr<VulkanSurfaceProducer> surface_producer_;
  flow::SceneUpdateContext scene_update_context_;
#ifndef SCENIC_VIEWS2
  OnMetricsUpdate metrics_changed_callback_;
#endif
  zx_handle_t vsync_event_handle_;

#ifndef SCENIC_VIEWS2
  void OnSessionEvents(fidl::VectorPtr<fuchsia::ui::scenic::Event> events);

#endif
  void EnqueueClearOps();

  void PresentSession();

  static void ToggleSignal(zx_handle_t handle, bool raise);

  FML_DISALLOW_COPY_AND_ASSIGN(SessionConnection);
};

}  // namespace flutter

#endif  // TOPAZ_RUNTIME_FLUTTER_RUNNER_SESSION_CONNECTION_H_
