// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "session_connection.h"

#include "lib/fidl/cpp/optional.h"
#include "lib/fxl/functional/make_copyable.h"
#include "lib/ui/scenic/fidl_helpers.h"
#include "vsync_waiter.h"

namespace flutter {

SessionConnection::SessionConnection(
    fidl::InterfaceHandle<fuchsia::ui::scenic::Scenic> scenic_handle,
#ifndef SCENIC_VIEWS2
    std::string debug_label, zx::eventpair import_token,
    OnMetricsUpdate session_metrics_did_change_callback,
    fit::closure session_error_callback, zx_handle_t vsync_event_handle)
#else
    fidl::InterfaceHandle<fuchsia::ui::scenic::Session> session,
    zx::eventpair view_token, std::string debug_label,
    fit::closure session_error_callback, zx_handle_t vsync_event_handle)
#endif
    : debug_label_(std::move(debug_label)),
      scenic_(scenic_handle.Bind()),
#ifndef SCENIC_VIEWS2
      session_wrapper_(scenic_.get()),
#else
      session_wrapper_(session.Bind(), nullptr),
      root_view_(&session_wrapper_, std::move(view_token), debug_label),
#endif
      root_node_(&session_wrapper_),
      surface_producer_(
          std::make_unique<VulkanSurfaceProducer>(&session_wrapper_)),
      scene_update_context_(&session_wrapper_, surface_producer_.get()),
#ifndef SCENIC_VIEWS2
      metrics_changed_callback_(std::move(session_metrics_did_change_callback)),
#endif
      vsync_event_handle_(vsync_event_handle) {
#ifndef SCENIC_VIEWS2
  session_wrapper_.set_error_handler(
      fxl::MakeCopyable(std::move(session_error_callback)));
  session_wrapper_.set_event_handler(std::bind(
      &SessionConnection::OnSessionEvents, this, std::placeholders::_1));
#else
  session_wrapper_.set_error_handler(std::move(session_error_callback));
#endif

#ifndef SCENIC_VIEWS2
  root_node_.Bind(std::move(import_token));
#else
  root_view_.AddChild(root_node_);
#endif
  root_node_.SetEventMask(fuchsia::ui::gfx::kMetricsEventMask);

#ifdef SCENIC_VIEWS2
  // TODO: move this into BaseView or ChildView
  root_node_.SetTranslation(0.f, 0.f, 0.1f);
#endif
  // Signal is initially high indicating availability of the session.
  ToggleSignal(vsync_event_handle_, true);

  PresentSession();
}

SessionConnection::~SessionConnection() = default;

#ifndef SCENIC_VIEWS2
void SessionConnection::OnSessionEvents(
    fidl::VectorPtr<fuchsia::ui::scenic::Event> events) {
  using Type = fuchsia::ui::gfx::Event::Tag;

  for (auto& raw_event : *events) {
    if (!raw_event.is_gfx()) {
      continue;
    }

    auto& event = raw_event.gfx();

    switch (event.Which()) {
      case Type::kMetrics: {
        if (event.metrics().node_id == root_node_.id()) {
          auto& metrics = event.metrics().metrics;
          double device_pixel_ratio = metrics.scale_x;
          scene_update_context_.set_metrics(
              fidl::MakeOptional(std::move(metrics)));
          if (metrics_changed_callback_) {
            metrics_changed_callback_(device_pixel_ratio);
          }
        }
      } break;
      default:
        break;
    }
  }
}

#endif
void SessionConnection::Present(flow::CompositorContext::ScopedFrame& frame) {
  // Flush all session ops. Paint tasks have not yet executed but those are
  // fenced. The compositor can start processing ops while we finalize paint
  // tasks.
  PresentSession();

  // Execute paint tasks and signal fences.
  auto surfaces_to_submit = scene_update_context_.ExecutePaintTasks(frame);

  // Tell the surface producer that a present has occurred so it can perform
  // book-keeping on buffer caches.
  surface_producer_->OnSurfacesPresented(std::move(surfaces_to_submit));

  // Prepare for the next frame. These ops won't be processed till the next
  // present.
  EnqueueClearOps();
}

void SessionConnection::EnqueueClearOps() {
  // We are going to be sending down a fresh node hierarchy every frame. So just
  // enqueue a detach op on the imported root node.
  session_wrapper_.Enqueue(scenic::NewDetachChildrenCmd(root_node_.id()));
}

void SessionConnection::PresentSession() {
  ToggleSignal(vsync_event_handle_, false);
  session_wrapper_.Present(0,  // presentation_time. (placeholder).
                           [handle = vsync_event_handle_](auto) {
                             ToggleSignal(handle, true);
                           }  // callback
  );
}

void SessionConnection::ToggleSignal(zx_handle_t handle, bool set) {
  const auto signal = flutter::VsyncWaiter::SessionPresentSignal;
  auto status = zx_object_signal(handle,            // handle
                                 set ? 0 : signal,  // clear mask
                                 set ? signal : 0   // set mask
  );
  if (status != ZX_OK) {
    FXL_LOG(ERROR) << "Could not toggle vsync signal: " << set;
  }
}

}  // namespace flutter
